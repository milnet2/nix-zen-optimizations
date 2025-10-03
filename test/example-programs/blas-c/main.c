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

// Minimal JSON string escaper for engine string
static void json_escape(const char* in, char* out, size_t out_len) {
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
      // control character -> skip or encode as space
      if (j + 6 >= out_len) break;
      // simple \u00XX encoding
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

  BlasHandle* h = blas_init(M, N, K);
  if (!h) { fprintf(stderr, "blas_init failed\n"); return 1; }

  // Time *just* the GEMM loop; init/finalize are excluded.
  double secs = blas_sgemm(h, A, B, C, M, N, K, repeats);
  double gflops = (2.0 * (double)M * (double)N * (double)K * repeats) / (secs * 1e9);
  float csum = checksum(C, M*N);

  // Output JSON
  double total_mb = (szA + szB + szC) / (1024.0 * 1024.0);
  unsigned long long total_bytes = (unsigned long long)(szA + szB + szC);
  printf("{\n");
  printf("  \"engine\": %s,\n", eng);
  printf("  \"M\": %d,\n", M);
  printf("  \"N\": %d,\n", N);
  printf("  \"K\": %d,\n", K);
  printf("  \"repeats\": %d,\n", repeats);
  printf("  \"bytes_total\": %llu,\n", total_bytes);
  printf("  \"megabytes_total\": %.1f,\n", total_mb);
  printf("  \"time_sec\": %.6f,\n", secs);
  printf("  \"gflops\": %.2f,\n", gflops);
  printf("  \"checksum\": %.6f\n", csum);
  printf("}\n");

  blas_finalize(h);
  free(A); free(B); free(C);
  return 0;
}
