{ stdenv, julia }:

stdenv.mkDerivation {
  pname = "buildinfo-julia";
  version = "1.0.0";

  src = ./.;
  buildInputs = [ julia ];

  buildPhase = ''
    chmod +x buildinfo.jl
    echo "Julia: ${julia}/bin/julia" > buildinfo.log
    ${julia}/bin/julia buildinfo.jl > buildinfo.json
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp buildinfo.jl $out/bin/
    chmod +x $out/bin/buildinfo.jl
    mkdir -p $out/lib
    cp buildinfo.log $out/lib
    cp buildinfo.json $out/lib
  '';

  meta = {
    description = "A Julia script that prints interpreter and system information in JSON format";
  };
}
