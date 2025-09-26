{ stdenv, R, rPackages, ... }:

stdenv.mkDerivation {
  pname = "buildinfo-r";
  version = "1.0.0";

  src = ./.;
  buildInputs = [ R rPackages.jsonlite ];

  buildPhase = ''
    chmod +x buildinfo.R
    echo "R: ${R}/bin/Rscript" > buildinfo.log
    ${R}/bin/Rscript buildinfo.R > buildinfo.json
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp buildinfo.R $out/bin/
    chmod +x $out/bin/buildinfo.R
    mkdir -p $out/lib
    cp buildinfo.log $out/lib
    cp buildinfo.json $out/lib
  '';

  meta = {
    description = "An R script that prints interpreter and system information in JSON format";
  };
}
