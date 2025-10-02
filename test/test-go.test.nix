# Unit tests
# See: https://nix-community.github.io/nix-unit/
# nix run --no-write-lock-file github:nix-community/nix-unit -- ./test-go.test.nix
{
   importablePkgsDelegate ? <nixpkgs>,
   lib ? (import importablePkgsDelegate {}).lib,
   pkgsTuned ? import ../zen-optimized-pkgs.nix {
        inherit importablePkgsDelegate lib;
        amdZenVersion = 2; # TODO: 5
        isLtoEnabled = true; },
    isAvx512Expected ? false,
}: let
    buildInfoProgram = pkgsTuned.callPackage ./example-programs/buildinfo-go {};
    buildInfoJson = builtins.fromJSON (builtins.readFile "${buildInfoProgram}/lib/buildinfo.json"); # Json was created by executing program
in {
    "test target arch is amd64" = {
        expr = buildInfoJson.target.arch;
        expected = "amd64";
    };

    "test go compiler type" = {
        expr = buildInfoJson.compiler.compiler;
        expected = "gc"; # The standard Go compiler
    };

    "test go version format" = {
        expr = builtins.match "go[0-9]+\\.[0-9]+(\\.[0-9]+)?" buildInfoJson.compiler.version_string != null;
        expected = true;
    };

    "test GOOS" = {
        expr = buildInfoJson.compiler.GOOS;
        expected = "linux";
    };

    "test GOAMD64 is v3 or v4" = {
        expr = (buildInfoJson.compiler.GOAMD64 == "v3") || (buildInfoJson.compiler.GOAMD64 == "v4") ;
        expected = true;
    };
}