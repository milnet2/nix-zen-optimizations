{ optimizedPlatform, unoptimizedPkgs,
    # TODO: packageOverrides,
    basePythonPackage ? pkgs: pkgs.python3Minimal,
    isLtoEnabled ? false,
    isAggressiveFastMathEnabled ? false,
}:
(final: prev: rec {
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
            }).overridePythonAttrs (old: {
                # Tests would fail because of lag of precision with fast-math enabled
                doCheck = old.doCheck && !isAggressiveFastMathEnabled;
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
                doCheck = old.doCheck && !isAggressiveFastMathEnabled;
                # TODO disabledTests = old.disabledTests ++
                #    (if isAggressiveFastMathEnabled then [ "test_float_types" "test_longdouble_precision" ] else []);
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
                # inherit (unoptimizedPkgs) tzdata; ->
                # Some tests signal through NAN. However, there's no NAN with fast-math. Thus we disable the tests for now.
                doCheck = false; # TODO: !isAggressiveFastMathEnabled; <= "No time zone found with key UTC"
                # pytest-xdist,
            });

            scipy = pyPrev.scipy.override {
                # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/scipy/default.nix
                inherit (final) blas lapack gfortran;
                inherit numpy;
            };
        };
      };

})