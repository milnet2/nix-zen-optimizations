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
  if (dladdr((void*)cblas_sgemm, &info) && info.dli_fname) {
    void* h = dlopen(info.dli_fname, RTLD_NOLOAD | RTLD_LAZY);
    if (h) provider = h;
  } else {
    info.dli_fname = NULL;
  }

  // --- Try OpenBLAS ---
  typedef const char* (*openblas_cfg_fn)(void); // openblas_get_config()
  openblas_cfg_fn openblas_get_config = (openblas_cfg_fn)dlsym(provider, "openblas_get_config");
  if (!openblas_get_config) {
    openblas_get_config = (openblas_cfg_fn)dlsym(RTLD_DEFAULT, "openblas_get_config");
  }
  if (openblas_get_config) {
    const char* cfg = openblas_get_config(); // e.g. "OpenBLAS 0.3.26 DYNAMIC_ARCH ..."
    snprintf(buf, len, "OpenBLAS: %s (%s)", cfg ? cfg : "unknown",
             info.dli_fname ? info.dli_fname : "unknown");
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
    snprintf(buf, len, "BLIS: %s (%s)", v ? v : "unknown",
             info.dli_fname ? info.dli_fname : "unknown");
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
    snprintf(buf, len, "%s (%s)", tmp,
             info.dli_fname ? info.dli_fname : "unknown");
    buf[len - 1] = '\0';
    if (provider != RTLD_DEFAULT && provider) dlclose(provider);
    return strlen(buf);
  }

  // --- Fallback: just print the provider .so path ---
  snprintf(buf, len, "BLAS library: %s",
           info.dli_fname ? info.dli_fname : "unknown");
  buf[len - 1] = '\0';
  if (provider != RTLD_DEFAULT && provider) dlclose(provider);
  return strlen(buf);
}
