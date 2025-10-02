#pragma once
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// Opaque handle so main doesn't know about CPU/GPU details
typedef struct BlasHandle BlasHandle;

// Prepare backend (may allocate GPU buffers, create handles, etc.)
BlasHandle* blas_init(int M, int N, int K);

// Run SGEMM repeatedly: C = A*B (alpha=1, beta=0), row-major, no-transpose
// A: MxK, B: KxN, C: MxN
// Returns total seconds spent inside the repeated GEMMs (excluding init/finalize).
double blas_sgemm(BlasHandle* h,
                  const float* A, const float* B, float* C,
                  int M, int N, int K,
                  int repeats);

// Cleanup backend (destroy handles, free device memory, etc.)
void blas_finalize(BlasHandle* h);

#ifdef __cplusplus
}
#endif
