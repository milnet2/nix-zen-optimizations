# Unit tests
# See: https://nix-community.github.io/nix-unit/
# nix run --no-write-lock-file github:nix-community/nix-unit -- ./test-python.test.nix
{
   importablePkgsDelegate ? <nixpkgs>,
   lib ? (import importablePkgsDelegate {}).lib,
   pkgsTuned ? import ../zen-optimized-pkgs.nix {
        inherit importablePkgsDelegate lib;
        amdZenVersion = 2; # TODO: 5
        isLtoEnabled = true; },
    isAvx512Expected ? false,
}: let
    buildInfoProgram = pkgsTuned.callPackage ./example-programs/buildinfo-python {};
    buildInfoJson = builtins.fromJSON (builtins.readFile "${buildInfoProgram}/lib/buildinfo.json"); # Json was created by executing program
in {
    "test target arch is x86_64" = {
        expr = buildInfoJson.target.arch;
        expected = "x86_64";
    };
    "test python version" = {
        expr = buildInfoJson.compiler.implementation;
        expected = "CPython";
    };
    "test python version format" = {
        expr = builtins.match "[0-9]+\\.[0-9]+\\.[0-9]+" buildInfoJson.compiler.version_string != null;
        expected = true;
    };
    "test python has version" = {
        expr = buildInfoJson.compiler.py_version > 0;
        expected = true;
    };
}