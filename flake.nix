{
    description = "Tuned Nixpkgs for AMD Zen with example programs and a dev shell";

    inputs = {
        nixpkgs.url = "github:nixos/nixpkgs/release-25.05";
        nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
        nix-unit = {
            # https://nix-community.github.io/nix-unit/examples/flakes.html
            url = "github:nix-community/nix-unit";
            inputs.nixpkgs.follows = "nixpkgs";
        };
    };

    outputs = { self, nixpkgs, nix-unit, ... }:
        let
            systems = [ "x86_64-linux" ];
            lib = nixpkgs.lib;
            forAllSystems = f: lib.genAttrs systems (system: f system);

            mkPkgsTuned = system:
                let
                    unoptimizedPkgs = import nixpkgs { inherit system; };
                in import ./zen-optimized-pkgs.nix {
                    importablePkgsDelegate = nixpkgs;
                    unoptimizedPkgs = unoptimizedPkgs;
                };
        in {
            # Expose the tuned package set so other flakes can consume it as pkgs
            # Example use: inputs.nix-zen-optimizations.legacyPackages.${system}
            legacyPackages = forAllSystems (system: mkPkgsTuned system);

            # Provide flake packages for the example programs (CPU-only where applicable)
            packages = forAllSystems (system:
                let
                    pkgsTuned = mkPkgsTuned system;
                in rec {
                    buildinfo-c      = pkgsTuned.callPackage ./test/example-programs/buildinfo-c/default.nix {};
                    buildinfo-cpp    = pkgsTuned.callPackage ./test/example-programs/buildinfo-cpp/default.nix {};
                    buildinfo-fortran= pkgsTuned.callPackage ./test/example-programs/buildinfo-fortran/default.nix {};
                    buildinfo-go     = pkgsTuned.callPackage ./test/example-programs/buildinfo-go/default.nix {};
                    buildinfo-haskell= pkgsTuned.callPackage ./test/example-programs/buildinfo-haskell/default.nix {};
                    buildinfo-python = pkgsTuned.callPackage ./test/example-programs/buildinfo-python/default.nix {};
                    buildinfo-r      = pkgsTuned.callPackage ./test/example-programs/buildinfo-r/default.nix {};
                    buildinfo-rust   = pkgsTuned.callPackage ./test/example-programs/buildinfo-rust/default.nix {};

                    # BLAS examples (CPU)
                    blas-c-cpu       = pkgsTuned.callPackage ./test/example-programs/blas-c/default.nix {
                        blas = pkgsTuned.blas;
                        isCpu = true;
                        pkg-config = pkgsTuned.pkg-config;
                    };
                    blas-fortran     = pkgsTuned.callPackage ./test/example-programs/blas-fortran/default.nix {
                        blas = pkgsTuned.blas;
                    };
                    blas-python      = pkgsTuned.callPackage ./test/example-programs/blas-python/default.nix {
                        enableTorch = false;
                    };
                }
            );

            # Development shell with the optimized example programs on PATH
            devShells = forAllSystems (system:
                let
                    pkgsTuned = mkPkgsTuned system;
                    ex = self.packages.${system};
                in rec {
                    default = examplesShell;
                    examplesShell = pkgsTuned.mkShell {
                        name = "nix-zen-optimizations-dev";
                        packages = [
                            ex.buildinfo-c
                            ex.buildinfo-cpp
                            ex.buildinfo-fortran
                            ex.buildinfo-go
                            ex.buildinfo-haskell
                            ex.buildinfo-python
                            ex.buildinfo-r
                            ex.buildinfo-rust
                            ex.blas-c-cpu
                            ex.blas-fortran
                            ex.blas-python
                        ];
                        shellHook = ''
                            echo "nix-zen-optimizations dev shell"
                            echo "Example programs are on PATH (some share names like 'buildinfo' or 'blas-test')."
                        '';
                    };
                }
            );

# TODO: This does not work as it would try to access the internet
#            checks = forAllSystems (system: {
#                default =
#                    nixpkgs.legacyPackages.${system}.runCommand "tests"
#                        {
#                            nativeBuildInputs = [ nix-unit.packages.${system}.default ];
#                            NIX_PATH = "nixpkgs=${nixpkgs}";
#                        }
#                        ''
#                            set -euo pipefail
#                            export HOME="$(realpath .)"
#                            nix-unit \
#                                --eval-store "$HOME" \
#                                --log-format bar \
#                                ${./.}/zen-optimized-pkgs.test.nix
#                            touch $out
#                        '';
#            });
    };
}
