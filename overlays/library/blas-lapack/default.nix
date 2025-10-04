
# See: /docu/blas-implementations.adoc

{ optimizedPlatform, unoptimizedPkgs, amdZenVersion ? 2 }:
(final: prev: rec {
    aocl-utils = prev.aocl-utils.override {
        # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/ao/aocl-utils/package.nix
        # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
    };

    amd-blis = prev.amd-blis.override {
        # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/am/amd-blis/package.nix#L70
        # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
        inherit (unoptimizedPkgs) perl; # TODO: Python
        blas64 = false; # TODO: check
        withOpenMP = true; # TODO: check
        withArchitecture = "zen${toString amdZenVersion}";
        inherit (unoptimizedPkgs) stdenv; # TODO Because of LTO
    };

    amd-libflame = prev.amd-libflame.override {
        # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/pkgs/by-name/am/amd-libflame/package.nix
        # TODO: We'd likely want fast-math here even if isAggressiveFastMathEnabled is disabled
        inherit amd-blis aocl-utils;
        inherit (unoptimizedPkgs) cmake;
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
            inherit (unoptimizedPkgs) cmake;
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
})