{ stdenv }:

stdenv.mkDerivation {
  name = "buildinfo-cpp";
  version = "1.0.0";
  
  src = ./.;
  buildInputs = [];

  buildPhase = ''
    $CXX -o buildinfo buildinfo.cpp $NIX_CXXFLAGS_COMPILE
    echo "$CXX -o buildinfo buildinfo.cpp $NIX_CXXFLAGS_COMPILE" >buildinfo.log
    ./buildinfo >buildinfo.json
  '';
  
  installPhase = ''
    mkdir -p $out/bin
    cp buildinfo $out/bin/buildinfo-cpp
    mkdir -p $out/lib
    cp buildinfo.log $out/lib
    cp buildinfo.json $out/lib
  '';
  
  meta = {
    description = "A C++ program that prints build information in JSON format";
  };
}