{ stdenv, ghc }:

stdenv.mkDerivation {
  name = "buildinfo-haskell";
  version = "1.0.0";

  src = ./.;
  nativeBuildInputs = [ ghc ];

  buildPhase = ''
    ${ghc}/bin/ghc -O2 -cpp \
      -optP-D__FAST_MATH__ \
      -optP-D__x86_64__=1 \
      -optP-D__SSE__ -optP-D__SSE2__ -optP-D__SSE3__ -optP-D__SSSE3__ -optP-D__SSE4_1__ -optP-D__SSE4_2__ \
      -optP-D__AVX__ -optP-D__AVX2__ \
      Main.hs -o buildinfo
    echo "${ghc}/bin/ghc -O2 -cpp -optP-D__FAST_MATH__ -optP-D__x86_64__=1 -optP-D__SSE__ -optP-D__SSE2__ -optP-D__SSE3__ -optP-D__SSSE3__ -optP-D__SSE4_1__ -optP-D__SSE4_2__ -optP-D__AVX__ -optP-D__AVX2__ Main.hs -o buildinfo" >buildinfo.log || true
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
