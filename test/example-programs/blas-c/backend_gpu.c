#include "backend.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef __has_include
#  if __has_include(<hip/hip_runtime.h>) && __has_include(<rocblas/rocblas.h>)
#    include <hip/hip_runtime.h>
#    include <rocblas/rocblas.h>
#  else
#    error "HIP/rocBLAS headers not found. Ensure ROCm dev packages are available."
#  endif
#endif

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

static void hip_check(hipError_t st, const char* what) {
  if (st != hipSuccess) {
    fprintf(stderr, "HIP %s failed: %s\n", what, hipGetErrorString(st));
    exit(1);
  }
}
static void rocblas_check(rocblas_status st, const char* what) {
  if (st != rocblas_status_success) {
    fprintf(stderr, "rocBLAS %s failed: status=%d\n", what, (int)st);
    exit(1);
  }
}

BlasHandle* blas_init(int M, int N, int K) {
  BlasHandle* h = (BlasHandle*)calloc(1, sizeof(BlasHandle));
  h->M = M; h->N = N; h->K = K;
  h->szA = (size_t)M * K * sizeof(float);
  h->szB = (size_t)K * N * sizeof(float);
  h->szC = (size_t)M * N * sizeof(float);

  rocblas_check(rocblas_create_handle(&h->handle), "create_handle");
  hip_check(hipMalloc((void**)&h->dA, h->szA), "hipMalloc(A)");
  hip_check(hipMalloc((void**)&h->dB, h->szB), "hipMalloc(B)");
  hip_check(hipMalloc((void**)&h->dC, h->szC), "hipMalloc(C)");
  return h;
}

double blas_sgemm(BlasHandle* h,
                  const float* A, const float* B, float* C,
                  int M, int N, int K,
                  int repeats) {
  // Sanity: use sizes from init (M,N,K should match)
  (void)M; (void)N; (void)K;

  hip_check(hipMemcpy(h->dA, A, h->szA, hipMemcpyHostToDevice), "Memcpy H2D A");
  hip_check(hipMemcpy(h->dB, B, h->szB, hipMemcpyHostToDevice), "Memcpy H2D B");
  hip_check(hipMemset(h->dC, 0, h->szC), "Memset C");

  const float alpha = 1.0f, beta = 0.0f;

  // Warmup
  rocblas_check(
        rocblas_sgemm(h->handle,
                      rocblas_operation_none, rocblas_operation_none,
                      /* m */ N, /* n */ M, /* k */ K,
                      &alpha,
                      /* A */ h->dB, /* lda */ N,
                      /* B */ h->dA, /* ldb */ K,
                      &beta,
                      /* C */ h->dC, /* ldc */ N),
    "sgemm warmup");
  hip_check(hipDeviceSynchronize(), "sync warmup");

  double t0 = now_sec();
  for (int r = 0; r < repeats; ++r) {
    rocblas_check(
        rocblas_sgemm(h->handle,
                      rocblas_operation_none, rocblas_operation_none,
                      /* m */ N, /* n */ M, /* k */ K,
                      &alpha,
                      /* A */ h->dB, /* lda */ N,
                      /* B */ h->dA, /* ldb */ K,
                      &beta,
                      /* C */ h->dC, /* ldc */ N),
      "sgemm");
  }
  hip_check(hipDeviceSynchronize(), "sync");
  double t1 = now_sec();

  hip_check(hipMemcpy(C, h->dC, h->szC, hipMemcpyDeviceToHost), "Memcpy D2H C");

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
