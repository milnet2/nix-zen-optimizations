{ stdenv, zig }:

stdenv.mkDerivation {
  name = "buildinfo-zig";
  version = "1.0.0";

  src = ./.;
  nativeBuildInputs = [ zig ];

  buildPhase = ''
    zig version > zig-version.txt
    # Use writable cache directories inside the sandbox TMPDIR to avoid $HOME/.cache writes
    zig build-exe buildinfo.zig -O ReleaseFast -mcpu=native -femit-bin=buildinfo \
      --cache-dir "$TMPDIR/zig-cache" --global-cache-dir "$TMPDIR/zig-global-cache"
    echo "zig build-exe buildinfo.zig -O ReleaseFast -mcpu=native -femit-bin=buildinfo --cache-dir $TMPDIR/zig-cache --global-cache-dir $TMPDIR/zig-global-cache" > buildinfo.log
    ./buildinfo > buildinfo.json
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp buildinfo $out/bin/
    mkdir -p $out/lib
    cp buildinfo.log $out/lib
    cp buildinfo.json $out/lib
  '';

  meta = {
    description = "A Zig program that prints build information in JSON format";
  };
}
