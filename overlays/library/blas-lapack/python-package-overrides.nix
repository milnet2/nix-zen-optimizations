{ optimizedPlatform, unoptimizedPkgs, isLtoEnabled ? false, isAggressiveFastMathEnabled ? false}:
final: prev: pyFinal: pyPrev: rec {
    numpy = (pyPrev.numpy.override {
        # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/numpy/2.nix
        inherit (final) blas lapack gfortran; # overridden on other overlays
        inherit hypothesis; # i.e. overridden somewhere here
        # inherit (unoptimizedPkgs) pytest-xdist;
    }).overridePythonAttrs (old: {
        # Tests would fail because of lag of precision with fast-math enabled
        doCheck = old.doCheck && !isAggressiveFastMathEnabled;
    });

    scipy = pyPrev.scipy.override {
        # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/scipy/default.nix
        inherit (final) blas lapack gfortran;
        inherit numpy;
    };
}