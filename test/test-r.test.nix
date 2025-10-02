# Unit tests
# See: https://nix-community.github.io/nix-unit/
# nix run --no-write-lock-file github:nix-community/nix-unit -- ./test-python.test.nix
{
   importablePkgsDelegate ? <nixpkgs>,
   lib ? (import importablePkgsDelegate {}).lib,
   pkgsTuned ? import ../zen-optimized-pkgs.nix {
        inherit importablePkgsDelegate lib;
        amdZenVersion = 2; # TODO: 5
        ltoLevel = "thin"; },
    isAvx512Expected ? false,
}: let
    buildInfoProgram = pkgsTuned.callPackage ./example-programs/buildinfo-r {};
    buildInfoJson = builtins.fromJSON (builtins.readFile "${buildInfoProgram}/lib/buildinfo.json"); # Json was created by executing program
in {
    "test target arch is x86_64" = {
        expr = buildInfoJson.platform.arch;
        expected = "x86_64";
    };
}