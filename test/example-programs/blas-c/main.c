#include "backend.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static double now_sec(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static void init_matrix(float* M, int rows, int cols, unsigned seed) {
  // deterministic fill, low overhead
  unsigned x = seed ? seed : 1u;
  for (int i = 0; i < rows * cols; ++i) {
    x = 1664525u * x + 1013904223u;
    M[i] = ((x >> 8) & 0xFFFF) / 32768.0f - 1.0f;
  }
}

static float checksum(const float* M, int n) {
  double s = 0.0;
  for (int i = 0; i < n; ++i) s += M[i];
  return (float)s;
}

int main(int argc, char** argv) {
  int N = (argc > 1) ? atoi(argv[1]) : 2048;
  int K = (argc > 2) ? atoi(argv[2]) : 2048;
  int repeats = (argc > 3) ? atoi(argv[3]) : 50;

  if (N <= 0 || K <= 0 || repeats <= 0) {
    fprintf(stderr, "Usage: %s [N] [K] [repeats]\n", argv[0]);
    return 1;
  }

  const int M = N; // square by default
  size_t szA = (size_t)M*K*sizeof(float);
  size_t szB = (size_t)K*N*sizeof(float);
  size_t szC = (size_t)M*N*sizeof(float);

  float* A = NULL; float* B = NULL; float* C = NULL;
  if (posix_memalign((void**)&A, 64, szA) != 0) { perror("alloc A"); return 1; }
  if (posix_memalign((void**)&B, 64, szB) != 0) { perror("alloc B"); return 1; }
  if (posix_memalign((void**)&C, 64, szC) != 0) { perror("alloc C"); return 1; }

  init_matrix(A, M, K, 1u);
  init_matrix(B, K, N, 2u);
  memset(C, 0, szC);

  char eng[256];
  blas_get_engine_info(eng, sizeof eng);
  printf("Engine: %s\n", eng);

  printf("Problem: M=%d N=%d K=%d  repeats=%d  (~%.1f MB)\n",
         M, N, K, repeats, (szA+szB+szC)/(1024.0*1024.0));

  BlasHandle* h = blas_init(M, N, K);
  if (!h) { fprintf(stderr, "blas_init failed\n"); return 1; }

  // Time *just* the GEMM loop; init/finalize are excluded.
  double secs = blas_sgemm(h, A, B, C, M, N, K, repeats);
  double gflops = (2.0 * (double)M * (double)N * (double)K * repeats) / (secs * 1e9);

  printf("Time: %.3f s   Perf: %.2f GFLOP/s   Checksum: %.6f\n",
         secs, gflops, checksum(C, M*N));

  blas_finalize(h);
  free(A); free(B); free(C);
  return 0;
}
