{ python3Packages, enableTorch ? false }:
with python3Packages;
let
  pythonEnv = python.withPackages (ps: [ ps.numpy ] ++ (if enableTorch then [ ps.pytorch ] else []));
in
buildPythonApplication {
  pname = "blas-test-python";
  version = "1.1.0";

  src = ./.; # expects: blas_test.py
  format = "other";

  # Keep explicit inputs for completeness; shebang will point to pythonEnv
  buildInputs = [ numpy ] ++ (if enableTorch then [ pytorch ] else []);

  outputs = [ "out" ];

  buildPhase = ''
    runHook preBuild
    chmod +x blas_test.py
    mkdir -p build
    cp blas_test.py build/blas-test
    substituteInPlace build/blas-test --replace "#!/usr/bin/env python3" "#!${pythonEnv}/bin/python"
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
