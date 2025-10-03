#define _GNU_SOURCE 1

#include "backend.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdio.h>
#include <dlfcn.h>

#ifdef __has_include
#  if __has_include(<hip/hip_runtime.h>) && __has_include(<rocblas/rocblas.h>)
#    include <hip/hip_runtime.h>
#    include <rocblas/rocblas.h>
#  else
#    error "HIP/rocBLAS headers not found. Ensure ROCm dev packages are available."
#  endif
#endif

// Minimal JSON escaper for strings included in engine JSON
static void json_escape_str(const char* in, char* out, size_t out_len) {
  if (!in || !out || out_len == 0) return;
  size_t j = 0;
  for (size_t i = 0; in[i] != '\0' && j + 1 < out_len; ++i) {
    unsigned char c = (unsigned char)in[i];
    if (c == '"' || c == '\\') {
      if (j + 2 >= out_len) break;
      out[j++] = '\\'; out[j++] = (char)c;
    } else if (c == '\n') {
      if (j + 2 >= out_len) break;
      out[j++] = '\\'; out[j++] = 'n';
    } else if (c == '\r') {
      if (j + 2 >= out_len) break;
      out[j++] = '\\'; out[j++] = 'r';
    } else if (c == '\t') {
      if (j + 2 >= out_len) break;
      out[j++] = '\\'; out[j++] = 't';
    } else if (c < 0x20) {
      if (j + 6 >= out_len) break;
      static const char hex[] = "0123456789abcdef";
      out[j++] = '\\'; out[j++] = 'u'; out[j++] = '0'; out[j++] = '0';
      out[j++] = hex[(c >> 4) & 0xF];
      out[j++] = hex[c & 0xF];
    } else {
      out[j++] = (char)c;
    }
  }
  out[j] = '\0';
}

struct BlasHandle {
  rocblas_handle handle;
  float *dA, *dB, *dC;
  size_t szA, szB, szC;
  int M, N, K;
};

static double now_sec(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec + ts.tv_nsec * 1e-9;
}

BlasHandle* blas_init(int M, int N, int K) {
  BlasHandle* h = (BlasHandle*)calloc(1, sizeof(BlasHandle));
  if (!h) return NULL;
  h->M = M; h->N = N; h->K = K;
  h->szA = (size_t)M * K * sizeof(float);
  h->szB = (size_t)K * N * sizeof(float);
  h->szC = (size_t)M * N * sizeof(float);

  rocblas_status rbst = rocblas_create_handle(&h->handle);
  if (rbst != rocblas_status_success) {
    fprintf(stderr, "rocBLAS create_handle failed: status=%d\n", (int)rbst);
    free(h);
    return NULL;
  }
  hipError_t ha = hipMalloc((void**)&h->dA, h->szA);
  if (ha != hipSuccess) {
    fprintf(stderr, "HIP hipMalloc(A) failed: %s\n", hipGetErrorString(ha));
    blas_finalize(h);
    return NULL;
  }
  hipError_t hb = hipMalloc((void**)&h->dB, h->szB);
  if (hb != hipSuccess) {
    fprintf(stderr, "HIP hipMalloc(B) failed: %s\n", hipGetErrorString(hb));
    blas_finalize(h);
    return NULL;
  }
  hipError_t hc = hipMalloc((void**)&h->dC, h->szC);
  if (hc != hipSuccess) {
    fprintf(stderr, "HIP hipMalloc(C) failed: %s\n", hipGetErrorString(hc));
    blas_finalize(h);
    return NULL;
  }
  return h;
}

double blas_sgemm(BlasHandle* h,
                  const float* A, const float* B, float* C,
                  int M, int N, int K,
                  int repeats) {
  // Sanity: use sizes from init (M,N,K should match)
  (void)M; (void)N; (void)K;

  hipError_t hst;
  hst = hipMemcpy(h->dA, A, h->szA, hipMemcpyHostToDevice);
  if (hst != hipSuccess) { fprintf(stderr, "HIP Memcpy H2D A failed: %s\n", hipGetErrorString(hst)); return -1.0; }
  hst = hipMemcpy(h->dB, B, h->szB, hipMemcpyHostToDevice);
  if (hst != hipSuccess) { fprintf(stderr, "HIP Memcpy H2D B failed: %s\n", hipGetErrorString(hst)); return -1.0; }
  hst = hipMemset(h->dC, 0, h->szC);
  if (hst != hipSuccess) { fprintf(stderr, "HIP Memset C failed: %s\n", hipGetErrorString(hst)); return -1.0; }

  const float alpha = 1.0f, beta = 0.0f;

  // Warmup
  rocblas_status rb;
  rb = rocblas_sgemm(h->handle,
                      rocblas_operation_none, rocblas_operation_none,
                      /* m */ N, /* n */ M, /* k */ K,
                      &alpha,
                      /* A */ h->dB, /* lda */ N,
                      /* B */ h->dA, /* ldb */ K,
                      &beta,
                      /* C */ h->dC, /* ldc */ N);
  if (rb != rocblas_status_success) { fprintf(stderr, "rocBLAS sgemm warmup failed: status=%d\n", (int)rb); return -1.0; }
  hst = hipDeviceSynchronize();
  if (hst != hipSuccess) { fprintf(stderr, "HIP sync warmup failed: %s\n", hipGetErrorString(hst)); return -1.0; }

  double t0 = now_sec();
  for (int r = 0; r < repeats; ++r) {
    rb = rocblas_sgemm(h->handle,
                      rocblas_operation_none, rocblas_operation_none,
                      /* m */ N, /* n */ M, /* k */ K,
                      &alpha,
                      /* A */ h->dB, /* lda */ N,
                      /* B */ h->dA, /* ldb */ K,
                      &beta,
                      /* C */ h->dC, /* ldc */ N);
    if (rb != rocblas_status_success) { fprintf(stderr, "rocBLAS sgemm failed: status=%d (iter=%d)\n", (int)rb, r); return -1.0; }
  }
  hst = hipDeviceSynchronize();
  if (hst != hipSuccess) { fprintf(stderr, "HIP sync failed: %s\n", hipGetErrorString(hst)); return -1.0; }
  double t1 = now_sec();

  hst = hipMemcpy(C, h->dC, h->szC, hipMemcpyDeviceToHost);
  if (hst != hipSuccess) { fprintf(stderr, "HIP Memcpy D2H C failed: %s\n", hipGetErrorString(hst)); return -1.0; }

  return t1 - t0;
}

void blas_finalize(BlasHandle* h) {
  if (!h) return;
  if (h->dA) hipFree(h->dA);
  if (h->dB) hipFree(h->dB);
  if (h->dC) hipFree(h->dC);
  if (h->handle) rocblas_destroy_handle(h->handle);
  free(h);
}

size_t blas_get_engine_info(char* buf, size_t len) {
  if (!buf || len == 0) return 0;
  buf[0] = '\0';

  // Identify the shared object that provides rocBLAS symbols
  Dl_info info;
  const char* so_path = NULL;
  if (dladdr((void*)rocblas_sgemm, &info) && info.dli_fname) {
    so_path = info.dli_fname;
  } else if (dladdr((void*)rocblas_get_version_string_size, &info) && info.dli_fname) {
    so_path = info.dli_fname;
  }
  char so_esc[512];
  json_escape_str(so_path ? so_path : "unknown", so_esc, sizeof so_esc);

  // rocBLAS version string
  char ver_buf[384] = {0};
  size_t need = 0;
  if (rocblas_get_version_string_size(&need) == rocblas_status_success && need > 0) {
    // Clamp to our buffer
    if (need >= sizeof(ver_buf)) need = sizeof(ver_buf) - 1;
    if (rocblas_get_version_string(ver_buf, sizeof(ver_buf)) != rocblas_status_success) {
      ver_buf[0] = '\0';
    }
  }
  char ver_esc[512];
  json_escape_str(ver_buf[0] ? ver_buf : "unknown", ver_esc, sizeof ver_esc);

  // HIP device properties (optional)
  int dev = 0; hipError_t hip_dev_st = hipGetDevice(&dev);
  hipDeviceProp_t p; hipError_t hip_prop_st = hip_dev_st == hipSuccess ? hipGetDeviceProperties(&p, dev) : hipErrorInvalidDevice;
  if (hip_prop_st == hipSuccess) {
    char name_esc[256], arch_esc[256];
    json_escape_str(p.name ? p.name : "unknown", name_esc, sizeof name_esc);
    json_escape_str(p.gcnArchName ? p.gcnArchName : "unknown", arch_esc, sizeof arch_esc);
    snprintf(buf, len,
             "{\"name\":\"rocBLAS\",\"version\":\"%s\",\"device\":{\"name\":\"%s\",\"arch\":\"%s\"}}",
             ver_esc, name_esc, arch_esc);
  } else {
    snprintf(buf, len,
             "{\"name\":\"rocBLAS\",\"version\":\"%s\"}",
             ver_esc);
  }
  buf[len - 1] = '\0';
  return strlen(buf);
}