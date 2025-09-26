# Provides a `pkgs` for optimized code
{
    importablePkgsDelegate ? <nixpkgs>, # The optimized packages will be based on this
    unoptimizedPkgs ? (import importablePkgsDelegate {}), # This is a `pkgs`. If we want a package without optimizations we'll pull it from here
    lib ? unoptimizedPkgs.lib,
    amdZenVersion ? 2, # We have 2 on the mini-pc
    ltoLevel ? "thin", # Param 'thin' has only effect on LLVM - gcc uses its own LTO
    optimizationParameter ? "-O3",
    noOptimizePkgs ? with unoptimizedPkgs; {
        inherit gnum4 bash bashNonInteractive bison gettext texinfo readline tzdata mailcap bluez-headers
            ncurses
            autoconf-archive autoreconfHook nukeReferences pkg-config # TODO: Good idea?
            # Hardly CPU-bund so we'll also skip
            sqlite gdbm
            ; }
}:
let
    # https://nixos.org/manual/nixpkgs/stable/#chap-cross
    optimizedPlatform = {
        system = "x86_64-linux";
        config = "x86_64-unknown-linux-gnu";
        libc = "glibc";
        useLLVM = false; # Would be faster building but cannot pick up the current optimizations for now

        # TODO: is*
        isAvx512 = (amdZenVersion > 4);

        platform = lib.systems.platforms.pc // {
            # See: https://github.com/NixOS/nixpkgs/blob/master/lib/systems/platforms.nix
            gcc = {
              arch = "znver${builtins.toString amdZenVersion}";
              tune = "znver${builtins.toString amdZenVersion}";
              # cpu = "";
            };
            go = {
              GOARCH = "amd64";
              # https://go.dev/wiki/MinimumRequirements#amd64
              GOAMD64 = if amdZenVersion > 4 then "v4" else "v3";
              GOFLAGS = "-ldflags=-s -w";
            };
            rust = {
                # https://rustc-dev-guide.rust-lang.org/building/optimized-build.html
                rustcTarget = "x86_64-unknown-linux-gnu";
                cargoShortTarget = "x86_64-unknown-linux-gnu";
                lto = ltoLevel;
            };
        };
    };

    # ---------------------------------------------
    # Overrides follow (programming languages)
    fortranOverlay = (final: prev: {
        gfortran = prev.symlinkJoin {
            name = "gfortran-${optimizedPlatform.platform.gcc.tune}";
            paths = [ prev.gfortran ];
            buildInputs = [ prev.makeWrapper ];
            # Classic Fortran flags; projects pick up FFLAGS/FCFLAGS, and Nix’s generic builder
            # respects NIX_FFLAGS_COMPILE similarly to NIX_CFLAGS_COMPILE.
            postBuild = ''
              wrapProgram $out/bin/gfortran \
                --set-default FFLAGS   "-O3 -pipe -fomit-frame-pointer -march=${optimizedPlatform.platform.gcc.arch} -mtune=${optimizedPlatform.platform.gcc.tune}" \
                --set-default FCFLAGS  "-O3 -pipe -fomit-frame-pointer -march=${optimizedPlatform.platform.gcc.arch} -mtune=${optimizedPlatform.platform.gcc.tune}" \
                --set-default NIX_FFLAGS_COMPILE "-O3 -pipe -fomit-frame-pointer -march=${optimizedPlatform.platform.gcc.arch} -mtune=${optimizedPlatform.platform.gcc.tune}"
            '';
        };}
    );

    goOverlay = (final: prev: {
        go = prev.symlinkJoin {
           # https://search.nixos.org/packages?channel=unstable&show=go&query=go
           name = "go-${optimizedPlatform.platform.go.GOARCH}-${optimizedPlatform.platform.go.GOAMD64}";
           paths = [ prev.go ];
           buildInputs = [ prev.makeWrapper ];
           postBuild = ''
               wrapProgram $out/bin/go \
                    --set-default GOARCH "${optimizedPlatform.platform.go.GOARCH}" \
                    --set-default GOAMD64 "${optimizedPlatform.platform.go.GOAMD64}" \
                    --set-default GOFLAGS "${optimizedPlatform.platform.go.GOFLAGS}"
               '';
        } // {
            inherit (prev.go) badTargetPlatforms passthru GOOS;
            # Preserve/define attributes used by some packages at eval-time
            GOARCH = "${optimizedPlatform.platform.go.GOARCH}";
            GOAMD64 = "${optimizedPlatform.platform.go.GOAMD64}";
            meta = prev.go.meta // {
                platforms = [ optimizedPlatform.platform ]; };
        };}
    );

    haskellOverlay = (final: prev: rec {
        ghc = prev.symlinkJoin {
           name = "ghc-${optimizedPlatform.platform.gcc.arch}";
           paths = [ prev.ghc ];
           buildInputs = [ prev.makeWrapper ];
           postBuild = ''
               wrapProgram $out/bin/ghc \
                      --set-default NIX_GHC_OPTS "-optc -march=${optimizedPlatform.platform.gcc.arch} -optc -mtune=${optimizedPlatform.platform.gcc.arch} -optlo -mcpu=${optimizedPlatform.platform.gcc.arch}"
               '';
        };
    });

    juliaOverlay = (final: prev: {
        julia = prev.julia.overrideAttrs (old: {
          # TODO
          # https://search.nixos.org/packages?channel=unstable&show=julia&query=julia
          # See https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/compilers/julia/generic.nix
          # Many channels expose these through make flags/env:
          # Aim to set a native/znver* target and link OpenBLAS Zen
          buildInputs = (old.buildInputs or []) ++ [ final.openblas ]; # There's an openblas override
          makeFlags = (old.makeFlags or []) ++ [
            "USE_BINARYBUILDER=0"    # build against Nix libs instead of prebuilt
          ];
        });
    });

    pythonOverlay = (final: prev: {
        # https://search.nixos.org/packages?channel=unstable&show=python3&query=python3
        python3 = (prev.python3.override {

         }).override {
            enableLTO = true;
            enableOptimizations = true; # Makes build non-reproducible!! # TODO: Enable "preferLocalBuild" setting
            reproducibleBuild = false; # only disables tests

            readline = unoptimizedPkgs.readline;
            tzdata = unoptimizedPkgs.tzdata;
            mailcap = unoptimizedPkgs.mailcap;
            bluez-headers = unoptimizedPkgs.bluez-headers;
            bashNonInteractive = unoptimizedPkgs.bashNonInteractive;

                packageOverrides = pyFinal: pyPrev: {
                  numpy = pyPrev.numpy.override {
                    blas = final.blas;
                    lapack = final.lapack;
                  };
                  scipy = pyPrev.scipy.override {
                    blas = final.blas;
                    lapack = final.lapack;
                  };
                };
              };
    });

    rOverlay = (final: prev: {
        # TODO: That's not a lot
        R = prev.R.override { blas = final.blas; lapack = final.lapack; };
    });

    rustOverlay = (final: prev: rec {
        rustc = prev.symlinkJoin {
           name = "rustc-${optimizedPlatform.platform.gcc.tune}";
           paths = [ prev.rustc ];
           buildInputs = [ prev.makeWrapper ];
           postBuild = ''
               wrapProgram $out/bin/rustc \
                   --set-default RUSTFLAGS "-C target-cpu=${optimizedPlatform.platform.gcc.tune} -C lto=${optimizedPlatform.platform.rust.lto} -C codegen-units=1"
           '';
        } // {
            inherit (prev.rustc) badTargetPlatforms;
            meta = prev.rustc.meta // {
                platforms = prev.rustc.meta.platforms ++ optimizedPlatform.platform; };
            targetPlatforms = [ optimizedPlatform.platform ];
        };
        cargo = prev.symlinkJoin {
            # https://search.nixos.org/packages?channel=unstable&show=cargo&query=cargo
            name = "cargo-${optimizedPlatform.platform.gcc.tune}";
            paths = [ prev.cargo ];
            buildInputs = [ prev.makeWrapper ];
            postBuild = ''
                wrapProgram $out/bin/cargo \
                    --set-default RUSTFLAGS "-C target-cpu=${optimizedPlatform.platform.gcc.tune} -C lto=${optimizedPlatform.platform.rust.lto} -C codegen-units=1"
            '';
        } // {
            inherit (prev.cargo) badTargetPlatforms;
            meta = prev.cargo.meta // {
                platforms = rustc.meta.platforms; };
            targetPlatforms = [ optimizedPlatform.platform ];
        };}
    );

    zigOverlay = (final: prev: {
        zig = prev.symlinkJoin {
            # https://search.nixos.org/packages?channel=unstable&show=zig&query=zig
            name = "zig-${optimizedPlatform.platform.gcc.tune}";
            paths = [ prev.zig ];
            buildInputs = [ prev.makeWrapper ];
            postBuild = ''
                wrapProgram $out/bin/zig --set-default ZIG_GLOBAL_ARGS "-mcpu=${optimizedPlatform.platform.gcc.tune}"
            '';
        };}
    );


    # ---------------------------------------------
    # Overrides follow (libraries)
    openBlasOverlay = (final: prev: rec {
        # https://search.nixos.org/packages?channel=unstable&show=openblas&query=openblas
        openblas = prev.openblas.override {
          # See https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/libraries/science/math/openblas/default.nix
          enableAVX512 = optimizedPlatform.isAvx512; # TODO: These kernels have been a source of trouble in the past.
          openmp = true;
          # See https://github.com/OpenMathLib/OpenBLAS/blob/develop/TargetList.txt
          target = "ZEN";
          dynamicArch = false;  # prefer fixed-target
        };

        # https://search.nixos.org/packages?channel=unstable&show=blas&query=blas
        blas = prev.blas.override { blasProvider = openblas; };
        # https://search.nixos.org/packages?channel=unstable&show=lapack&query=lapack
        lapack = prev.lapack.override { lapackProvider = openblas; };
    });

    # TODO: OpenMP

in import importablePkgsDelegate rec {
    config.allowUnfree = true;
    localSystem = optimizedPlatform;
    inherit noOptimizePkgs;

    overlays = [
       (final: prev: noOptimizePkgs)

       fortranOverlay
       goOverlay
       haskellOverlay
       juliaOverlay
       pythonOverlay
       rOverlay
       # rustOverlay # TODO: Broken!
       zigOverlay

       openBlasOverlay
    ];

    config.replaceStdenv = { pkgs, ...}:
        let
            baseStdenv = pkgs.gcc14Stdenv; # TODO: Or pkgs.gcc_latest.stdenv? or pkgs.llvmPackages_latest.stdenv?
            stenvAdapter = pkgs.callPackage ./helper/my-stenv-adapter.nix {};
        in
            stenvAdapter.wrapStdenv {
                inherit baseStdenv;
                extraCFlagsCompile = [ optimizationParameter "-fomit-frame-pointer" "-ffast-math"
                    "-march=${optimizedPlatform.platform.gcc.arch}" "-mtune=${optimizedPlatform.platform.gcc.tune}"
                    "-flto=auto" "-fipa-icf" ];
                extraCFlagsLink = [ "-flto=auto" ]; # TODO: Parameter mot yet picked up properly
                extraCPPFlagsCompile = [ "-DNDEBUG" ]; # TODO: Parameter mot yet picked up properly
                extraLdFlags = [ "--as-needed" "--gc-sections" ];
                extraHardeningDisable = [ "fortify" ]; # TODO: Parameter mot yet picked up properly

                # TODO: Do we want to also change `libc`?
            };
}