{ stdenv, python3 }:

stdenv.mkDerivation {
  name = "buildinfo-python";
  version = "1.0.0";
  
  src = ./.;
  buildInputs = [ python3 ];

  buildPhase = ''
    chmod +x buildinfo.py
    echo "Python: ${python3.interpreter}" >buildinfo.log
    echo "PYTHONPATH: $PYTHONPATH" >>buildinfo.log
    ${python3.interpreter} buildinfo.py >buildinfo.json
  '';
  
  installPhase = ''
    mkdir -p $out/bin
    cp buildinfo.py $out/bin/
    chmod +x $out/bin/buildinfo.py
    mkdir -p $out/lib
    cp buildinfo.log $out/lib
    cp buildinfo.json $out/lib
  '';
  
  meta = {
    description = "A Python program that prints interpreter and system information in JSON format";
  };
}