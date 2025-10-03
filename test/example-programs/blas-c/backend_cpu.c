#define _GNU_SOURCE 1

#include "backend.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <dlfcn.h>
#include <stdio.h>

#ifdef __has_include
#  if __has_include(<cblas.h>)
#    include <cblas.h>
#  else
#    error "cblas.h not found. Link against BLAS (e.g., amd-blis) and provide headers."
#  endif
#endif

typedef const char* (*blis_ver_fn)(void);          // bli_info_get_version_str()
typedef char*       (*openblas_cfg_fn)(void);      // openblas_get_config()
typedef void        (*mkl_get_ver_fn)(char*, int); // mkl_get_version_string()

// Minimal JSON escaper for strings we include in the engine JSON
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

struct BlasHandle { int dummy; };

static double now_sec(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec + ts.tv_nsec * 1e-9;
}

BlasHandle* blas_init(int M, int N, int K) {
  (void)M; (void)N; (void)K;
  BlasHandle* h = (BlasHandle*)calloc(1, sizeof(BlasHandle));
  return h;
}

double blas_sgemm(BlasHandle* h,
                  const float* A, const float* B, float* C,
                  int M, int N, int K,
                  int repeats) {
  (void)h;
  const float alpha = 1.0f, beta = 0.0f;

  // Warmup
  cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
              M, N, K, alpha, A, K, B, N, beta, C, N);

  double t0 = now_sec();
  for (int r = 0; r < repeats; ++r) {
    cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans,
                M, N, K, alpha, A, K, B, N, beta, C, N);
  }
  double t1 = now_sec();
  return t1 - t0;
}

void blas_finalize(BlasHandle* h) {
  free(h);
}

size_t blas_get_engine_info(char* buf, size_t len) {
  if (!buf || len == 0) return 0;
  buf[0] = '\0';

  // Identify the shared object that provides cblas_sgemm
  Dl_info info;
  void* provider = RTLD_DEFAULT;
  const char* so_path = NULL;
  if (dladdr((void*)cblas_sgemm, &info) && info.dli_fname) {
    void* h = dlopen(info.dli_fname, RTLD_NOLOAD | RTLD_LAZY);
    if (h) provider = h;
    so_path = info.dli_fname;
  }
  char so_esc[512];
  json_escape_str(so_path ? so_path : "unknown", so_esc, sizeof so_esc);

  // --- Try OpenBLAS ---
  typedef const char* (*openblas_cfg_fn)(void); // openblas_get_config()
  openblas_cfg_fn openblas_get_config = (openblas_cfg_fn)dlsym(provider, "openblas_get_config");
  if (!openblas_get_config) {
    openblas_get_config = (openblas_cfg_fn)dlsym(RTLD_DEFAULT, "openblas_get_config");
  }
  if (openblas_get_config) {
    const char* cfg = openblas_get_config(); // e.g. "OpenBLAS 0.3.26 DYNAMIC_ARCH ..."
    char cfg_esc[512];
    json_escape_str(cfg ? cfg : "unknown", cfg_esc, sizeof cfg_esc);
    snprintf(buf, len, "{\"name\":\"OpenBLAS\",\"config\":\"%s\"}", cfg_esc);
    buf[len - 1] = '\0';
    if (provider != RTLD_DEFAULT && provider) dlclose(provider);
    return strlen(buf);
  }

  // --- Try BLIS / AOCL-BLIS ---
  typedef const char* (*blis_ver_fn)(void); // bli_info_get_version_str()
  blis_ver_fn blis_get_ver = (blis_ver_fn)dlsym(provider, "bli_info_get_version_str");
  if (!blis_get_ver) {
    blis_get_ver = (blis_ver_fn)dlsym(RTLD_DEFAULT, "bli_info_get_version_str");
  }
  if (blis_get_ver) {
    const char* v = blis_get_ver(); // e.g. "AOCL-BLIS 4.1.0 ..."
    char v_esc[512];
    json_escape_str(v ? v : "unknown", v_esc, sizeof v_esc);
    snprintf(buf, len, "{\"name\":\"BLIS\",\"version\":\"%s\"}", v_esc);
    buf[len - 1] = '\0';
    if (provider != RTLD_DEFAULT && provider) dlclose(provider);
    return strlen(buf);
  }

  // --- Try Intel oneMKL ---
  typedef void (*mkl_get_ver_fn)(char*, int); // mkl_get_version_string()
  mkl_get_ver_fn mkl_get_version_string =
      (mkl_get_ver_fn)dlsym(RTLD_DEFAULT, "mkl_get_version_string");
  if (mkl_get_version_string) {
    char tmp[192] = {0};
    mkl_get_version_string(tmp, (int)sizeof(tmp));
    char ver_esc[256];
    json_escape_str(tmp[0] ? tmp : "unknown", ver_esc, sizeof ver_esc);
    snprintf(buf, len, "{\"name\":\"MKL\",\"version\":\"%s\"}", ver_esc);
    buf[len - 1] = '\0';
    if (provider != RTLD_DEFAULT && provider) dlclose(provider);
    return strlen(buf);
  }

  // --- Fallback ---
  snprintf(buf, len, "{\"name\":\"Unknown\"}");
  buf[len - 1] = '\0';
  if (provider != RTLD_DEFAULT && provider) dlclose(provider);
  return strlen(buf);
}
