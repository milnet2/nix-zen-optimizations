{ stdenv, blas-test, m ? 2048, n ? 2048, iterations ? 10 }:
stdenv.mkDerivation {
  name = "blas-test-python-result";
  version = "1.0.0";

  src = ./.;
  buildInputs = [ blas-test ];

  buildPhase = ''
    set +e
    ${blas-test}/bin/blas-test ${toString m} ${toString n} ${toString iterations} >result.json
    set -e
  '';

  installPhase = ''
    mkdir -p $out/lib
    cp *.json $out/lib
  '';
}
