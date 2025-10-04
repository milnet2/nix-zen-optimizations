# Unit tests
# See: https://nix-community.github.io/nix-unit/
# nix run --no-write-lock-file github:nix-community/nix-unit -- ./zen-optimized-pkgs.test.nix
{
   importablePkgsDelegate ? <nixpkgs>,
   lib ? (import importablePkgsDelegate {}).lib,
}: let
    pkgsTuned = import ./zen-optimized-pkgs.nix {
        inherit importablePkgsDelegate lib;
        amdZenVersion = 2; # TODO: 5
        isLtoEnabled = true; };
    isAvx512Expected = false;
in {
    "Optimized C compilation" =
        import ./test/test-c.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };

    "Optimized C++ compilation" =
        import ./test/test-cpp.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };

    "Go environment" =
        import ./test/test-go.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };

    "Optimized Fortran compilation" =
        import ./test/test-fortran.test.nix { inherit importablePkgsDelegate lib
            pkgsTuned isAvx512Expected; };

    "Optimized Haskell compilation" =
        import ./test/test-haskell.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };

    "Python environment" =
        import ./test/test-python.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };

    "R environment" =
        import ./test/test-r.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };

    "Rust environment" =
        import ./test/test-rust.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };
}
