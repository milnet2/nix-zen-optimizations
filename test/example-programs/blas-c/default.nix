{ stdenv
, lib
, blas                  # e.g. pkgs.amd-blis (CPU build)
, rocblas ? null        # e.g. pkgs.rocmPackages.rocblas (GPU build)
, clr ? null                # GPU: e.g. pkgs.rocmPackages.clr (HIP runtime headers/libs)
, hipcc ? null              # optional: pkgs.rocmPackages.hipcc
, pkg-config ? null
, isCpu ? true
}:
let
    buildCpuBlas = ''
      echo "== CPU build with CBLAS (e.g. amd-blis, OpenBLAS, ...)"
      # Try pkg-config for CBLAS; fall back to common flags if not available.
      CFLAGS_EXTRA="$(pkg-config --cflags cblas 2>/dev/null || true)"
      LDLIBS_EXTRA="$(pkg-config --libs   cblas 2>/dev/null || echo "-lcblas -lblas")"

      $CC -o build/blas-test-cpu main.c backend_cpu.c $CFLAGS_EXTRA $LDLIBS_EXTRA -ldl
    '';
    buildCpuPlain = ''
      echo "== CPU build (plain)"
      $CC -o build/blas-test-cpu main.c backend_plain.c -ldl
    '';
    buildGpuCc = ''
      echo "== GPU build with rocBLAS C-Compiler"
      HIP_INCLUDES="-I${clr}/include"
      ROCBLAS_INCLUDES="-I${rocblas}/include"

      echo "HIP_INCLUDES=$HIP_INCLUDES"
      echo "ROCBLAS_INCLUDES=$ROCBLAS_INCLUDES"

      $CC -o build/blas-test-gpu main.c backend_gpu.c $HIP_INCLUDES $ROCBLAS_INCLUDES -L${rocblas}/lib -lrocblas -L${clr}/lib -lamdhip64 -D__HIP_PLATFORM_AMD__=1
    '';
    buildGpuHip = ''
      echo "== GPU build with rocBLAS/HIP"
      # Prefer hipcc for correct ROCm link args. Treat sources as C++.

      ${lib.getExe' hipcc "hipcc"} -O3 -std=c++17 -x c++ \
                -I${clr}/include -I${rocblas}/include \
                -L${rocblas}/lib -lrocblas \
                -L${clr}/lib -lamdhip64 \
                -D__HIP_PLATFORM_AMD__=1 \
                -o build/blas-test-gpu \
                main.c backend_gpu.c
    '';

    actualBuild =
        (if isCpu then
            (if (blas != null) then buildCpuBlas else buildCpuPlain)
        else # GPU
            (if (hipcc != null) then buildGpuHip else buildGpuCc));
in
stdenv.mkDerivation {
  pname = "blas-test";
  version = "1.0.0";

  src = ./.;  # expects: main.c backend.h backend_cpu.c backend_gpu.c

  nativeBuildInputs = [ pkg-config ];

  buildInputs =
    (if isCpu then [ blas ] else [ rocblas clr ]);

  # Name artifact differently so you can install both variants
  # (optional; you can keep a single name if you prefer)
  outputs = [ "out" ];
  postPatch = ''
    # nothing to patch
  '';

  buildPhase = ''
    runHook preBuild
    mkdir -p build

    ${actualBuild}

    runHook postBuild
    '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    if [ ${lib.boolToString isCpu} = true ]; then
      install -Dm755 build/blas-test-cpu $out/bin/blas-test
    else
      install -Dm755 build/blas-test-gpu $out/bin/blas-test
    fi
    runHook postInstall
  '';

  meta = with lib; {
    description = "Backend-agnostic BLAS benchmark (CPU via CBLAS/BLIS, GPU via rocBLAS) with backend selected by Nix inputs";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
