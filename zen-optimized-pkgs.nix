# Provides a `pkgs` for optimized code
{
    importablePkgsDelegate ? <nixpkgs>,
    lib ? (import importablePkgsDelegate {}).lib,
    amdZenVersion ? 2, # We have 2 on the mini-pc
    ltoLevel ? "thin",
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
        python3 = (prev.python3.override { })
              .override {
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

    config.replaceStdenv = { pkgs, ...}:
        assert pkgs.stdenv.isLinux; #  pkgs.llvmPackages_latest.stdenv
        # See: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/build-support/cc-wrapper/default.nix
        pkgs.overrideCC pkgs.stdenv (pkgs.wrapCCWith {
           cc = pkgs.gcc_latest.cc;
           nativeTools = false;
           nativeLibc = false; # TODO libc = "glibc"; # - name or package?
           # TODO: Setting Linker -Wl,--icf=all breaks builds!
           extraBuildCommands = ''
               echo "export NIX_CFLAGS_COMPILE+=' -O3 -pipe -fomit-frame-pointer -ffast-math -march=${optimizedPlatform.platform.gcc.arch} -mtune=${optimizedPlatform.platform.gcc.tune}'" >> $out/nix-support/setup-hook
               # echo "export NIX_CFLAGS_COMPILE+=' -flto=${ltoLevel}'" >> $out/nix-support/setup-hook
               # echo "export NIX_CFLAGS_LINK+=' -flto=${ltoLevel}'" >> $out/nix-support/setup-hook
               # echo "export NIX_LDFLAGS+=' -Wl,-O3 -Wl,--as-needed -Wl,--gc-sections'" >> $out/nix-support/setup-hook
               echo "export NIX_CPPFLAGS_COMPILE+=' -DNDEBUG'" >> $out/nix-support/setup-hook
               echo "export NIX_HARDENING_DISABLE+=' fortify'" >> $out/nix-support/setup-hook
           '';
       });

    overlays = [
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
}