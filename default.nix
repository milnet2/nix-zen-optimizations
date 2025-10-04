{
    importablePkgsDelegate ? <nixpkgs>, # The optimized packages will be based on this
    unoptimizedPkgs ? (import importablePkgsDelegate {}), # This is a `pkgs`. If we want a package without optimizations we'll pull it from here
    lib ? unoptimizedPkgs.lib,
    amdZenVersion ? 2, # We have 2 on the mini-pc
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
import ./zen-optimized-pkgs.nix {
    inherit importablePkgsDelegate
            unoptimizedPkgs
            lib
            amdZenVersion
            basePythonPackage
            noOptimizePkgs;
}