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
    isAggressiveFastMathEnabled ? false, # Will cause loss of precision and also some tests to fail (=> some tests will get disabled)
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

        jdk

        ncurses libssh2 unzip
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

    # The stdenvs are templates with different optimizations applied to them.
    # We'll use them to mix-and-match later...
    stdenvs = import ./helper/stdenvs.nix {
        baseStdenv = unoptimizedPkgs.gcc15Stdenv; # TODO: Or pkgs.gcc_latest.stdenv? or pkgs.llvmPackages_latest.stdenv?
        inherit importablePkgsDelegate unoptimizedPkgs amdZenVersion optimizationParameter; };

    # ---------------------------------------------
    # Overlay imports follow

    fortranOverlay = import ./overlays/compiler/fortran/default.nix { inherit optimizedPlatform; };
    goOverlay = import ./overlays/compiler/go/default.nix { inherit optimizedPlatform unoptimizedPkgs isLtoEnabled; };
    haskellOverlay = import ./overlays/compiler/haskell/default.nix { inherit optimizedPlatform unoptimizedPkgs; };
    rustOverlay = import ./overlays/compiler/rust/default.nix { inherit optimizedPlatform unoptimizedPkgs isLtoEnabled; };
    pythonOverlay = import ./overlays/interpreter/python/default.nix { inherit optimizedPlatform unoptimizedPkgs basePythonPackage isLtoEnabled isAggressiveFastMathEnabled; };
    rOverlay = import ./overlays/library/blas-lapack/default.nix { inherit optimizedPlatform unoptimizedPkgs; };
    openBlasOverlay = import ./overlays/library/blas-lapack/default.nix { inherit optimizedPlatform unoptimizedPkgs amdZenVersion; };
    rOverlay = import ./overlays/interpreter/r/default.nix { inherit optimizedPlatform unoptimizedPkgs; };
    # TODO: OpenMP ??

in import importablePkgsDelegate rec {
    #inherit (unoptimizedPkgs) config;
    config.allowUnfree = true;
    localSystem = optimizedPlatform;

    inherit noOptimizePkgs;

    overlays = [
        # Order matters!
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
        if (isAggressiveFastMathEnabled) then stdenvs.withAggressiveFastMath else stdenvs.safeTweaks;
}