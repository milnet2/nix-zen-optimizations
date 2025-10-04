{ optimizedPlatform, unoptimizedPkgs, isLtoEnabled ? false, isAggressiveFastMathEnabled ? false }:
final: prev: pyFinal: pyPrev: rec {

# --------------------------------------------------------------------
# Build tools

    # XXX: meson is not overridable
#                meson = unoptimizedPkgs.pythonPackages.meson;
#                meson = (pyPrev.meson.override {
#                    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/me/meson/package.nix
#                    inherit (unoptimizedPkgs) coreutils ninja zlib;
#                    # TODO: llvmPackages.openmp
#                });

# --------------------------------------------------------------------
# C interop

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
        doCheck = old.doCheck && !isAggressiveFastMathEnabled;
        # TODO disabledTests = old.disabledTests ++
        #    (if isAggressiveFastMathEnabled then [ "test_float_types" "test_longdouble_precision" ] else []);
    });

# --------------------------------------------------------------------
# Testing

#                pytest-xdist = (pyPrev.pytest-xdist.override {
#                    # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/pytest-xdist/default.nix
#                    inherit execnet; # py: psutil;
#                });
#
#                execnet = (pyPrev.execnet.override {
#                     # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/execnet/default.nix
#                     inherit (unoptimizedPkgs) ; # py: hatchling hatch-vcs gevent
#                });

    hypothesis = (pyPrev.hypothesis.override {
        # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/hypothesis/default.nix
        # inherit (unoptimizedPkgs) tzdata; ->
        # Some tests signal through NAN. However, there's no NAN with fast-math. Thus we disable the tests for now.
        doCheck = false; # TODO: !isAggressiveFastMathEnabled; <= "No time zone found with key UTC"
        # pytest-xdist,
    });

# --------------------------------------------------------------------
# Misc libraries

    gevent = (pyPrev.gevent.override {
        # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/gevent/default.nix
        inherit (unoptimizedPkgs) libuv;
        inherit cffi cython;
    });

}