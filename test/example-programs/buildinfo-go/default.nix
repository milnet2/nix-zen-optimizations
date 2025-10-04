{ stdenv, buildGoModule }:

buildGoModule {
  pname = "buildinfo-go";
  version = "1.0.0";

  src = ./.;

  # Since we have no external dependencies, we can set a dummy hash
  vendorHash = null;

  # Ensure we're using the optimized compiler flags
  buildPhase = ''
    echo "Build using $(readlink -f $(command -v go))"

    go build -ldflags="-X 'main.goamd64=$(go env GOAMD64)' -X 'main.goflags=$(go env GOFLAGS)'" -o buildinfo buildinfo.go
    ./buildinfo > buildinfo.json
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp buildinfo $out/bin/buildinfo-go
    mkdir -p $out/lib
    cp buildinfo.json $out/lib
  '';

  meta = {
    description = "A Go program that prints build information in JSON format";
    platforms = [ "x86_64-linux" ];
  };
}
