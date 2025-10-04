{ stdenv
, lib
, blas                  # e.g. pkgs.amd-blis (CPU build)
, gfortran              # compiler
, pkg-config ? null
}: 

stdenv.mkDerivation {
  pname = "blas-test-fortran";
  version = "1.0.0";

  src = ./.; # expects: main.f90

  nativeBuildInputs = [ gfortran pkg-config ];
  buildInputs = [ blas ];

  outputs = [ "out" ];

  buildPhase = ''
    runHook preBuild
    mkdir -p build
    # Prefer pkg-config if available to find BLAS
    FFLAGS_EXTRA="$(pkg-config --cflags blas 2>/dev/null || true)"
    LDLIBS_EXTRA="$(pkg-config --libs   blas 2>/dev/null || echo "-lblas")"

    ${gfortran}/bin/gfortran -O3 -fno-unsafe-math-optimizations -o build/blas-test main.f90 $FFLAGS_EXTRA $LDLIBS_EXTRA

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 build/blas-test $out/bin/blas-test-f90
    runHook postInstall
  '';

  meta = with lib; {
    description = "Fortran BLAS SGEMM benchmark printing JSON (CPU via BLAS)";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
