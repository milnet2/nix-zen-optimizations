#include "backend.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef __has_include
#  if __has_include(<cblas.h>)
#    include <cblas.h>
#  else
#    error "cblas.h not found. Link against BLAS (e.g., amd-blis) and provide headers."
#  endif
#endif

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
