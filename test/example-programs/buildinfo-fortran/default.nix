{ stdenv, gfortran }:

stdenv.mkDerivation {
  name = "buildinfo-fortran";
  version = "1.0.0";
  
  src = ./.;
  nativeBuildInputs = [ gfortran ];

  buildPhase = ''
    ${gfortran}/bin/gfortran -cpp -ffast-math \
      -D__x86_64__=1 \
      -D__SSE__ -D__SSE2__ -D__SSE3__ -D__SSSE3__ -D__SSE4_1__ -D__SSE4_2__ \
      -D__AVX__ -D__AVX2__ \
      -o buildinfo buildinfo.F90 $NIX_CFLAGS_COMPILE
    echo "${gfortran}/bin/gfortran -cpp -ffast-math -D__x86_64__=1 -D__SSE__ -D__SSE2__ -D__SSE3__ -D__SSSE3__ -D__SSE4_1__ -D__SSE4_2__ -D__AVX__ -D__AVX2__ -o buildinfo buildinfo.F90 $NIX_CFLAGS_COMPILE" >buildinfo.log || true
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
    description = "A Fortran program that prints build information in JSON format";
  };
}
