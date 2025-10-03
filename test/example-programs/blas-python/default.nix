{ stdenv, lib, python3 }:

stdenv.mkDerivation {
  pname = "blas-test-python";
  version = "1.0.0";

  src = ./.; # expects: blas_test.py

  # Need numpy for SGEMM via BLAS
  buildInputs = [ (python3.withPackages (ps: with ps; [ numpy ])) ];

  outputs = [ "out" ];

  buildPhase = ''
    runHook preBuild
    chmod +x blas_test.py
    mkdir -p build
    cp blas_test.py build/blas-test
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    install -Dm755 build/blas-test $out/bin/blas-test
    runHook postInstall
  '';

  meta = with lib; {
    description = "Python/NumPy SGEMM benchmark printing JSON (CPU via BLAS through NumPy)";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
