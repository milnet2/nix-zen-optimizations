{ stdenv, ghc }:

stdenv.mkDerivation {
  name = "buildinfo-haskell";
  version = "1.0.0";

  src = ./.;
  nativeBuildInputs = [ ghc ];

  buildPhase = ''
    echo ${ghc}/bin/ghc -cpp Main.hs -o buildinfo >>buildinfo.log
    ${ghc}/bin/ghc -cpp Main.hs -o buildinfo
    ./buildinfo >buildinfo.json
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp buildinfo $out/bin/
    mkdir -p $out/lib
    cp buildinfo.log $out/lib || true
    cp buildinfo.json $out/lib
  '';

  meta = {
    description = "A Haskell program that prints build information in JSON format";
  };
}
