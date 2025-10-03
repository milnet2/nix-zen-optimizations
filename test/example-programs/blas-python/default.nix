{ stdenv, lib, python3, enableTorch ? false }:

stdenv.mkDerivation {
  pname = "blas-test-python";
  version = "1.1.0";

  src = ./.; # expects: blas_test.py

  # NumPy for CPU; optionally add PyTorch for GPU backend
  buildInputs = [ (python3.withPackages (ps: with ps; ([ numpy ] ++ (if enableTorch then [ pytorch ] else [])))) ];

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
    description = "Python SGEMM benchmark printing JSON (CPU via NumPy/BLAS; optional GPU via PyTorch CUDA/ROCm)";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
