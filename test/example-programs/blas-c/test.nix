{ stdenv, blas-test, m ? 2048, n ? 2048, iterations ? 10, spoofGpu ? null }:
stdenv.mkDerivation {
  name = "blas-test-result";
  version = "1.0.0";

  src = ./.;
  buildInputs = [ blas-test ];

  buildPhase =
    if (spoofGpu != null) then
        ''HSA_OVERRIDE_GFX_VERSION='${spoofGpu}' ${blas-test}/bin/blas-test ${toString m} ${toString n} ${toString iterations} 2>&1 >result.json''
    else
        ''${blas-test}/bin/blas-test ${toString m} ${toString n} ${toString iterations} 2>&1 >result.json'';

  installPhase = ''
    mkdir -p $out/lib
    cp *.json $out/lib
  '';
}