{ stdenv }:

stdenv.mkDerivation {
  name = "buildinfo";
  version = "1.0.0";
  
  src = ./.;
  buildInputs = [];

  buildPhase = ''
    $CC -o buildinfo buildinfo.c $NIX_CFLAGS_COMPILE
    echo "$CC -o buildinfo buildinfo.c $NIX_CFLAGS_COMPILE" >buildinfo.log
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