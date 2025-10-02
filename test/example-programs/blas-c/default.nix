{ stdenv
, lib
, blas                  # e.g. pkgs.amd-blis (CPU build)
, rocblas ? null        # e.g. pkgs.rocmPackages.rocblas (GPU build)
, hip ? null            # e.g. pkgs.rocmPackages.hip (GPU build: provides hipcc/headers)
, pkg-config ? null
, isCpu ? true
}:
let
    buildCpu = ''
      echo "== CPU build with CBLAS (e.g. amd-blis)"
      # Try pkg-config for CBLAS; fall back to common flags if not available.
      CFLAGS_EXTRA="$(pkg-config --cflags cblas 2>/dev/null || true)"
      LDLIBS_EXTRA="$(pkg-config --libs   cblas 2>/dev/null || echo "-lcblas -lblas")"

      ${stdenv.cc.targetPrefix}cc -O3 -march=native -fopenmp \
        $CFLAGS $CFLAGS_EXTRA \
        -o build/blas-test-cpu \
        main.c backend_cpu.c \
        $LDFLAGS $LDLIBS_EXTRA
    '';
    buildGpu = ''
      echo "== GPU build with rocBLAS/HIP"
      # Prefer hipcc for correct ROCm link args. Treat sources as C++.
      HIPCC=${hip}/bin/hipcc

      "$HIPCC" -O3 -std=c++17 \
        -o build/blas-test-gpu \
        -x c++ main.c backend_gpu.c \
        -I${hip}/include -I${rocblas}/include \
        -L${rocblas}/lib -lrocblas

      # If you prefer gcc/clang instead of hipcc, you could do:
      # ${stdenv.cc.targetPrefix}cc -O3 -o build/blas-test-gpu \
      #   main.c backend_gpu.c -I${hip}/include -I${rocblas}/include \
      #   -L${rocblas}/lib -lrocblas -L${hip}/lib -lamdhip64
    '';
in
stdenv.mkDerivation {
  pname = "blas-test";
  version = "1.0.0";

  src = ./.;  # expects: main.c backend.h backend_cpu.c backend_gpu.c

  nativeBuildInputs = [ pkg-config ];

  buildInputs =
    (if isCpu then [ blas ] else [ rocblas hip ]);

  # Name artifact differently so you can install both variants
  # (optional; you can keep a single name if you prefer)
  outputs = [ "out" ];
  postPatch = ''
    # nothing to patch
  '';

  buildPhase = ''
    runHook preBuild

    mkdir -p build
    '' +
    ( if isCpu then buildCpu else buildGpu) +
    ''

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
