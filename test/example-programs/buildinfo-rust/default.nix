{ stdenv, rustc }:

stdenv.mkDerivation {
  name = "buildinfo-rust";
  version = "1.0.0";

  src = ./.;
  buildInputs = [ rustc ];

  buildPhase = ''
    export BUILD_DATE="$(date +%Y-%m-%d)"
    export BUILD_TIME="$(date +%H:%M:%S)"

    echo "NIX_RUSTFLAGS=$NIX_RUSTFLAGS" > buildinfo.log
    ${rustc}/bin/rustc -o buildinfo buildinfo.rs
    echo "${rustc}/bin/rustc -o buildinfo buildinfo.rs" >> buildinfo.log
    ./buildinfo > buildinfo.json
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp buildinfo $out/bin/buildinfo-rs
    mkdir -p $out/lib
    cp buildinfo.log $out/lib
    cp buildinfo.json $out/lib
  '';

  meta = {
    description = "A Rust program that prints build information in JSON format";
  };
}
