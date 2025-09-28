{ stdenv }:

stdenv.mkDerivation {
  name = "buildinfo";
  version = "1.0.0";
  
  src = ./.;
  buildInputs = [];

  buildPhase = ''
    set -eo pipefail

    echo "$CC -o buildinfo buildinfo.c"
    $CC -o buildinfo buildinfo.c
    echo "Build complete"

    echo "CC=$(readlink -f $(command -v $CC))" >>buildinfo.log
    echo "NIX_CFLAGS_COMPILE=$NIX_CFLAGS_COMPILE" >>buildinfo.log
    echo "NIX_CFLAGS_LINK=$NIX_CFLAGS_LINK" >>buildinfo.log
    echo "NIX_LDFLAGS=$NIX_LDFLAGS" >>buildinfo.log
    echo "CFLAGS_COMPILE=$CFLAGS_COMPILE" >>buildinfo.log
    echo "CFLAGS=$CFLAGS" >>buildinfo.log
    echo "LDFLAGS=$LDFLAGS" >>buildinfo.log

    ./buildinfo >buildinfo.json
  '';
  
  installPhase = ''
    mkdir -p $out/bin
    cp buildinfo $out/bin/
    mkdir -p $out/lib
    cp buildinfo.log $out/lib
    cp buildinfo.json $out/lib
  '';
  
  meta = {
    description = "A program that prints build information in JSON format";
  };
}