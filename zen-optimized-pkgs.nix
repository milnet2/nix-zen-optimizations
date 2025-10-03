# Provides a `pkgs` for optimized code.

# See documentation at docu/zen-optimized-pkgs.adoc
# See documentation at docu/zen-optimized-pkgs.adoc
# See documentation at docu/zen-optimized-pkgs.adoc

# tag::header[]
{
    importablePkgsDelegate ? <nixpkgs>, # The optimized packages will be based on this
    unoptimizedPkgs ? (import importablePkgsDelegate {}), # This is a `pkgs`. If we want a package without optimizations we'll pull it from here
    lib ? unoptimizedPkgs.lib,
    amdZenVersion ? 2, # We have 2 on the mini-pc
    isLtoEnabled ? false, # Be careful with that: It will easily break stuff
    isAggressiveFastMathEnabled ? true, # Will cause loss of precision and also some tests to fail (=> some tests will get disabled)
    optimizationParameter ? "-O3",
    basePythonPackage ? pkgs: pkgs.python3Minimal,
    noOptimizePkgs ? with unoptimizedPkgs; { inherit
# end::header[]
        # CAUTION: Be careful what you add here. If it transitively pulls in stuff from unoptimizedPkgs.pkgs
        # The build will fail. ... At the very end :(
        # bash bashNonInteractive ncurses diffutils findutils

        nasm perl curl # TODO: Perl still seems to be built anyways
        glibc-locales tzdata mailcap bluez-headers

        cmake tradcpp git dejagnu meson
        adns tcl libuv libffi
            #autoconf-archive autoreconfHook nukeReferences # TODO: Good idea?
#            gawk
        expat readline
        gnum4 ninja pkg-config bison gettext texinfo

        tex texlive texliveSmall xetex texlive-scripts pdftex luatex luahbtex graphviz ghostscript pango asciidoc
        docbook docbook-xml
        fontforge fontconfig libXft
        xorg # xorgproto libXt libX11
        libtiff libjpeg

        rocmPackages # I think, these typically use their own compiler (hipcc) anyways

        jdk # TODO: Optimize this?

        ncurses libssh2
        libpfm openssl bash-interactive
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
              GOOS = "linux";
              GOARCH = "amd64";
              # https://go.dev/wiki/MinimumRequirements#amd64
              GOAMD64 = if amdZenVersion > 4 then "v4" else "v3";
            };
            rust = {
                # https://rustc-dev-guide.rust-lang.org/building/optimized-build.html
                rustcTarget = "x86_64-unknown-linux-gnu";
                cargoShortTarget = "x86_64-unknown-linux-gnu";
            } // (if isLtoEnabled then { lto = "thin"; } else {}) ;
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

    goOverlay = (final: prev: rec {
        go = prev.symlinkJoin {
           # https://search.nixos.org/packages?channel=unstable&show=go&query=go
           name = "go-${optimizedPlatform.platform.go.GOARCH}-${optimizedPlatform.platform.go.GOAMD64}";
           paths = [ unoptimizedPkgs.go ];
           buildInputs = [ unoptimizedPkgs.makeWrapper ];
           # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/setup-hooks/make-wrapper.sh
           postBuild = ''
               wrapProgram $out/bin/go \
                    --set GOOS "${optimizedPlatform.platform.go.GOOS}" \
                    --set GOARCH "${optimizedPlatform.platform.go.GOARCH}" \
                    --set GOAMD64 "${optimizedPlatform.platform.go.GOAMD64}" \
                    --set-default CGO_CFLAGS "${optimizationParameter} -fomit-frame-pointer -ffast-math -march=${optimizedPlatform.platform.gcc.arch} -mtune=${optimizedPlatform.platform.gcc.tune} ${if isLtoEnabled then "-flto=auto" else ""} -fipa-icf" \
                    --set-default CGO_LDFLAGS "--as-needed --gc-sections"
               '';
        } // {
            inherit (unoptimizedPkgs.go) badTargetPlatforms CGO_ENABLED;
            GOOS = optimizedPlatform.platform.go.GOOS;
            GOARCH = optimizedPlatform.platform.go.GOARCH;
            GOAMD64 = optimizedPlatform.platform.go.GOAMD64;
            meta = unoptimizedPkgs.go.meta // {
                platforms = [ optimizedPlatform.platform ]; };
        };

        buildGoModule = prev.buildGoModule.override {
            # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/go/module.nix
            inherit go;
        };
        }
    );

    haskellOverlay = (final: prev: rec {
        # Need to compile-in LLVM into the systems ghc as it doesn't have this enabled by default and
        # some optimizations only seem to be available through LLVM
        ghcWithLlvm = ((unoptimizedPkgs.ghc)  # (unoptimizedPkgs.haskell.compiler.ghcHEAD)
            .override {
                useLLVM = true;
                # buildTargetLlvmPackages = false;
            });
        ghc = let
            llvmFlags = [
                "-mcpu=${optimizedPlatform.platform.gcc.tune}"
                "-enable-unsafe-fp-math"
                "-enable-no-nans-fp-math"
                "-enable-no-infs-fp-math"
                "-enable-no-signed-zeros-fp-math"
                ];
            llvmFlagsGhcWrapped = toString ( map (x: "-optlc " + x) llvmFlags);
        in prev.symlinkJoin {
           name = "ghc-${optimizedPlatform.platform.gcc.arch}";
           paths = [ ghcWithLlvm ];
           buildInputs = [ unoptimizedPkgs.makeWrapper ];
           # https://downloads.haskell.org/ghc/latest/docs/users_guide/flags.html
           postBuild = ''
               wrapProgram $out/bin/ghc \
                      --add-flags "${optimizationParameter} -fllvm ${llvmFlagsGhcWrapped}"
               '';
        };
    });

    pythonOverlay = (final: prev: {
        # https://search.nixos.org/packages?channel=unstable&show=python3&query=python3
        python3 = (basePythonPackage prev).override {
            enableLTO = isLtoEnabled;
            enableOptimizations = true; # Makes build non-reproducible!! # TODO: Enable "preferLocalBuild" setting
            reproducibleBuild = false; # only disables tests

            gdbm = null; withGdbm = false;
            readline = unoptimizedPkgs.readline; withReadline = false;
            tzdata = unoptimizedPkgs.tzdata;
            mailcap = unoptimizedPkgs.mailcap;
            bluezSupport = false; # bluez-headers = unoptimizedPkgs.bluez-headers;
            bashNonInteractive = unoptimizedPkgs.bashNonInteractive;

            testers = [];

            packageOverrides = pyFinal: pyPrev: rec {
                numpy = (pyPrev.numpy.override {
                    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/numpy/2.nix
                    inherit (final) blas lapack gfortran; # overridden on other overlays
                    inherit hypothesis; # i.e. overridden somewhere here
                    # inherit (unoptimizedPkgs) pytest-xdist;
                    pytest-xdist = null; # TODO: That's a bit harsh!
                }).overridePythonAttrs (old: {
                    # TODO: Test if we may run these with fast-math
                    doCheck = !isAggressiveFastMathEnabled;
                });

                cython = (pyPrev.cython.override {
                    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/cython/default.nix
                    inherit (unoptimizedPkgs) gdb ncurses;
                    inherit numpy;
                });

                cffi = (pyPrev.cffi.override {
                   # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/cffi/default.nix
                   inherit (unoptimizedPkgs) libffi;
                }).overridePythonAttrs (old: {
                    # Currently some tests fail on float precision. likely due to aggressive fast-math
                    doCheck = !isAggressiveFastMathEnabled;
                });

                # XXX: meson is not overridable
#                meson = unoptimizedPkgs.pythonPackages.meson;
#                meson = (pyPrev.meson.override {
#                    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/me/meson/package.nix
#                    inherit (unoptimizedPkgs) coreutils ninja zlib;
#                    # TODO: llvmPackages.openmp
#                });


#                pytest-xdist = (pyPrev.pytest-xdist.override {
#                    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/pytest-xdist/default.nix
#                    inherit execnet; # py: psutil;
#                });
#
#                execnet = (pyPrev.execnet.override {
#                     # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/execnet/default.nix
#                     inherit (unoptimizedPkgs) ; # py: hatchling hatch-vcs gevent
#                });

                gevent = (pyPrev.gevent.override {
                    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/gevent/default.nix
                    inherit (unoptimizedPkgs) libuv;
                    inherit cffi cython;
                });

                hypothesis = (pyPrev.hypothesis.override {
                    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/hypothesis/default.nix
                    inherit (unoptimizedPkgs) tzdata;
                    # Some tests signal through NAN. However, there's no NAN with fast-math. Thus we disable the tests for now.
                    doCheck = !isAggressiveFastMathEnabled;
                    # pytest-xdist,
                });

                scipy = pyPrev.scipy.override {
                    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/scipy/default.nix
                    inherit (final) blas lapack gfortran;
                    inherit numpy;
                };
            };
          };
    });

    rOverlay = (final: prev: {
        R = (prev.R.override {
            inherit (noOptimizePkgs)
                perl ncurses curl readline texinfo bison jdk tzdata
                texlive texliveSmall graphviz pango
                libtiff libjpeg;
            libX11 = noOptimizePkgs.xorg.libX11;
            libXt = noOptimizePkgs.xorg.libXt;
            inherit (final) blas lapack;

            inherit (unoptimizedPkgs) stdenv gfortran; # TODO Because of LTO - TODO: Optimized? - match GCC version
        })
        .overrideAttrs (old: {
            doCheck = false; # TODO: These have different flags in grDevices-Ex
            env = (old.env or {}) // {
                # Try to avoid test flakyness
                OMP_NUM_THREADS        = "1";
                OPENBLAS_NUM_THREADS   = "1";
                BLIS_NUM_THREADS       = "1";
                GOTO_NUM_THREADS       = "1";
                VECLIB_MAXIMUM_THREADS = "1";
                MKL_NUM_THREADS        = "1";
            };
          });
    });

    rustOverlay = (final: prev: rec {
        rustc = prev.symlinkJoin {
           name = "rustc-${optimizedPlatform.platform.gcc.tune}";
           paths = [ unoptimizedPkgs.rustc ];
           buildInputs = [ unoptimizedPkgs.makeWrapper ];
           postBuild = ''
               wrapProgram $out/bin/rustc \
                   --add-flags "-C target-cpu=${optimizedPlatform.platform.gcc.tune} ${if isLtoEnabled then "-C lto=${optimizedPlatform.platform.rust.lto}" else ""} -C codegen-units=1"
           '';
        } // {
            inherit (unoptimizedPkgs.rustc) badTargetPlatforms;
            meta = unoptimizedPkgs.rustc.meta // {
                platforms = unoptimizedPkgs.rustc.meta.platforms ++ optimizedPlatform.platform; };
            targetPlatforms = [ optimizedPlatform.platform ];
        };
        cargo = prev.symlinkJoin {
            # https://search.nixos.org/packages?channel=unstable&show=cargo&query=cargo
            name = "cargo-${optimizedPlatform.platform.gcc.tune}";
            paths = [ unoptimizedPkgs.cargo ];
            buildInputs = [ unoptimizedPkgs.makeWrapper ];
            postBuild = ''
                wrapProgram $out/bin/cargo \
                    --set NIX_RUSTFLAGS "-C target-cpu=${optimizedPlatform.platform.gcc.tune} ${if isLtoEnabled then "-C lto=${optimizedPlatform.platform.rust.lto}" else ""}  -C codegen-units=1"
            '';
        } // {
            inherit (prev.cargo) badTargetPlatforms;
            meta = unoptimizedPkgs.cargo.meta // {
                platforms = rustc.meta.platforms; };
            targetPlatforms = [ optimizedPlatform.platform ];
        };}
    );

    # ---------------------------------------------
    # Overrides follow (libraries)

# See: docu/blas-implementations.adoc
# tag::openBlasOverlay[]
    openBlasOverlay = (final: prev: rec {
        aocl-utils = prev.aocl-utils.override {
            # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/ao/aocl-utils/package.nix
            # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
        };

        amd-blis = prev.amd-blis.override {
            # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/am/amd-blis/package.nix#L70
            # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
            inherit (noOptimizePkgs) perl; # TODO: Python
            blas64 = false; # TODO: check
            withOpenMP = true; # TODO: check
            withArchitecture = "zen${toString amdZenVersion}";
            inherit (unoptimizedPkgs) stdenv; # TODO Because of LTO
        };

        amd-libflame = prev.amd-libflame.override {
            # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/am/amd-libflame/package.nix
            # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
            inherit amd-blis aocl-utils;
            inherit (noOptimizePkgs) cmake;
            inherit (final) gfortran;
            blas64 = false; # TODO: check
            withOpenMP = true; # TODO: check
            withAMDOpt = true;
        };

        # https://search.nixos.org/packages?channel=unstable&show=openblas&query=openblas
        openblas = prev.openblas.override {
          # See https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/libraries/science/math/openblas/default.nix
          # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
          enableAVX512 = optimizedPlatform.isAvx512; # TODO: These kernels have been a source of trouble in the past.
          openmp = true;
          # See https://github.com/OpenMathLib/OpenBLAS/blob/develop/TargetList.txt
          target = "ZEN";
          dynamicArch = false;  # prefer fixed-target
        };

        lapack-reference = prev.lapack-reference # AKA liblapack
            .override {
                # https://search.nixos.org/packages?channel=25.05&show=lapack-reference&query=liblapack
                # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/la/lapack-reference/package.nix
                # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
                inherit (final) gfortran;
                inherit (noOptimizePkgs) cmake;
                inherit (unoptimizedPkgs) stdenv; # TODO Because of LTO
            };

        blas = prev.blas.override {
            # https://search.nixos.org/packages?channel=unstable&show=blas&query=blas
            # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/bl/blas/package.nix
            # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
            inherit openblas lapack-reference;
            blasProvider = final.amd-blis;
        };

        # See also: la-pack https://github.com/ROCm/rocm-libraries

        lapack = prev.lapack.override {
            # https://search.nixos.org/packages?channel=unstable&show=lapack&query=lapack
            # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/la/lapack/package.nix
            # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
            inherit openblas lapack-reference;
            lapackProvider = final.amd-libflame;
        };
    });
# end::openBlasOverlay[]

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
       rustOverlay

       openBlasOverlay

       pythonOverlay
       rOverlay
    ];

    config.replaceStdenv = { pkgs, ...}:
        let
            baseStdenv = pkgs.gcc15Stdenv; # TODO: Or pkgs.gcc_latest.stdenv? or pkgs.llvmPackages_latest.stdenv?
            stenvAdapter = pkgs.callPackage ./helper/my-stenv-adapter.nix {};
        in
            stenvAdapter.wrapStdenv {
                inherit baseStdenv;
                extraCFlagsCompile = [ optimizationParameter "-fomit-frame-pointer"
                    "-march=${optimizedPlatform.platform.gcc.arch}" "-mtune=${optimizedPlatform.platform.gcc.tune}"
                    "-fipa-icf" ] ++
                    (if isAggressiveFastMathEnabled then [ "-ffast-math" ] else []);
                extraCFlagsLink = [ ]; # TODO: Parameter mot yet picked up properly
                extraCPPFlagsCompile = [ "-DNDEBUG" ]; # TODO: Parameter mot yet picked up properly
                extraLdFlags = [ "--as-needed" "--gc-sections" ];
                extraHardeningDisable = [ "fortify" ]; # TODO: Parameter mot yet picked up properly

                # TODO: Do we want to also change `libc`?
            };
}