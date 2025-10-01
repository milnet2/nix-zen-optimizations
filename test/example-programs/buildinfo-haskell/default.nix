{ stdenv, ghc }:

stdenv.mkDerivation {
  name = "buildinfo-haskell";
  version = "1.0.0";

  src = ./.;
  nativeBuildInputs = [ ghc ];

  # Optimizations will only be applied by LLVM so these aren't available from the Haskell-code
  # We'll inspect the *.s files for that.
  buildPhase = ''
    ghc -keep-llvm-files -keep-s-files -cpp Main.hs -o buildinfo
    ./buildinfo >buildinfo.json
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp buildinfo $out/bin/
    mkdir -p $out/lib
    cp buildinfo.log $out/lib || true
    cp buildinfo.json $out/lib
    cp *.ll *.s *.S $out/lib
  '';

  meta = {
    description = "A Haskell program that prints build information in JSON format";
  };
}
