
# See: /docu/blas-implementations.adoc

{ optimizedPlatform, unoptimizedPkgs, stdenvs, amdZenVersion ? 2,

    stdenvBlis ? stdenvs.upstream,              # TODO: Or withAggressiveFastMath - but never:withLto
    stdenvOpenBlas ? stdenvs.safeTweaks,        #
    stdenvLibflame ? stdenvs.safeTweaks,        # TODO: I think, this can do LTO. We likely also want fast-math
    stdenvLapack ? stdenvs.safeTweaks,          # No LTO here!

    stdenvLapackReference ? stdenvLapack, # No LTO here!
    stdenvBlas ? stdenvLapackReference,
}:
let
    isUseOpenMP = true;
in (final: prev: rec {
    aocl-utils = prev.aocl-utils.override {
        # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/ao/aocl-utils/package.nix
        # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
    };

    amd-blis = prev.amd-blis.override {
        # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/am/amd-blis/package.nix#L70
        stdenv = stdenvBlis;

        inherit (unoptimizedPkgs) perl; # TODO: Python
        blas64 = false; # TODO: check
        withOpenMP = isUseOpenMP; # TODO: check
        withArchitecture = "zen${toString amdZenVersion}";
    };

    amd-libflame = prev.amd-libflame.override {
        # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/am/amd-libflame/package.nix
        stdenv = stdenvLibflame;

        inherit amd-blis aocl-utils;
        inherit (unoptimizedPkgs) cmake;
        inherit (final) gfortran;
        blas64 = false; # TODO: check
        withOpenMP = isUseOpenMP; # TODO: check
        withAMDOpt = true;
    };

    # https://search.nixos.org/packages?channel=unstable&show=openblas&query=openblas
    openblas = prev.openblas.override {
        # See https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/libraries/science/math/openblas/default.nix
        # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
        stdenv = stdenvOpenBlas;

        enableAVX512 = optimizedPlatform.isAvx512; # TODO: These kernels have been a source of trouble in the past.
        openmp = isUseOpenMP;
        # See https://github.com/OpenMathLib/OpenBLAS/blob/develop/TargetList.txt
        target = "ZEN";
        dynamicArch = false;  # prefer fixed-target
    };

    lapack-reference = prev.lapack-reference # AKA liblapack
        .override {
            # https://search.nixos.org/packages?channel=25.05&show=lapack-reference&query=liblapack
            # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/la/lapack-reference/package.nix
            stdenv = stdenvLapackReference;
            inherit (final) gfortran;
            inherit (unoptimizedPkgs) cmake;
        };

    blas = prev.blas.override {
        # https://search.nixos.org/packages?channel=unstable&show=blas&query=blas
        # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/bl/blas/package.nix
        stdenv = stdenvBlas;

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
})