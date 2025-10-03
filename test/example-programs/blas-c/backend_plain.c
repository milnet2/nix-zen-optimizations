#define _GNU_SOURCE 1

#include "backend.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdio.h>

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

static inline void sgemm_plain_rowmajor(const float* A, const float* B, float* C,
                                        int M, int N, int K) {
  // Compute C = A * B with row-major layout, no transposes, alpha=1, beta=0.
  // A: MxK, B: KxN, C: MxN
  for (int i = 0; i < M; ++i) {
    float* Ci = C + (size_t)i * N;
    const float* Ai = A + (size_t)i * K;
    for (int j = 0; j < N; ++j) {
      float sum = 0.0f;
      for (int k = 0; k < K; ++k) {
        sum += Ai[k] * B[(size_t)k * N + j];
      }
      Ci[j] = sum;
    }
  }
}

double blas_sgemm(BlasHandle* h,
                  const float* A, const float* B, float* C,
                  int M, int N, int K,
                  int repeats) {
  (void)h;
  // Warmup once (not timed)
  sgemm_plain_rowmajor(A, B, C, M, N, K);

  double t0 = now_sec();
  for (int r = 0; r < repeats; ++r) {
    sgemm_plain_rowmajor(A, B, C, M, N, K);
  }
  double t1 = now_sec();
  return t1 - t0;
}

void blas_finalize(BlasHandle* h) {
  free(h);
}

size_t blas_get_engine_info(char* buf, size_t len) {
  if (!buf || len == 0) return 0;
  // Minimal JSON engine descriptor to align with main.c printer
  const char* s = "{\"name\":\"PlainC\"}";
  size_t n = strlen(s);
  if (n + 1 > len) n = len - 1;
  memcpy(buf, s, n);
  buf[n] = '\0';
  return n;
}
