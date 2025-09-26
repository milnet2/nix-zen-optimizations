{ stdenv, buildGoModule }:

buildGoModule {
  pname = "buildinfo-go";
  version = "1.0.0";

  src = ./.;

  # Since we have no external dependencies, we can set a dummy hash
  vendorHash = null;

  # Ensure we're using the optimized compiler flags
  buildPhase = ''
    # Log the go build command for debugging
    echo "go build -o buildinfo buildinfo.go" > buildinfo.log

    # Build the Go program
    go build -o buildinfo buildinfo.go

    # Run the program to generate the JSON output
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
    description = "A Go program that prints build information in JSON format";
  };
}
