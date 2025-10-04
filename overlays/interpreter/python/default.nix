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

        packageOverrides = pyFinal: pyPrev:
            (import ./python-package-overrides.nix
                { inherit optimizedPlatform unoptimizedPkgs isLtoEnabled isAggressiveFastMathEnabled; }
                final prev pyFinal pyPrev) //
            (import ./../../library/blas-lapack/python-package-overrides.nix
                { inherit optimizedPlatform unoptimizedPkgs isLtoEnabled isAggressiveFastMathEnabled; }
                final prev pyFinal pyPrev) //
            { };
      };
})