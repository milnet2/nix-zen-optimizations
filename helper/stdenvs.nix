
# See documentation at ../docu/stdenvs.adoc
# See documentation at ../docu/stdenvs.adoc
# See documentation at ../docu/stdenvs.adoc

{
    importablePkgsDelegate ? <nixpkgs>, # The optimized packages will be based on this
    unoptimizedPkgs ? (import importablePkgsDelegate {}), # This is a `pkgs`. If we want a package without optimizations we'll pull it from here
    baseStdenv ? unoptimizedPkgs.gcc15Stdenv,
    amdZenVersion ? 2, # We have 2 on the mini-pc
    optimizationParameter ? "-O3",
}:
let
    cpuNameCc = "znver${toString amdZenVersion}";
    cpuNameGo = if amdZenVersion > 4 then "v4" else "v3"; # variable AMD64
    ltoEnabledParam = if unoptimizedPkgs.stdenv.cc.isClang then "--lto=thin" else "--lto=auto";
    hardeningFlags = []; # TODO: Do we want to keep some?

    stenvAdapter = unoptimizedPkgs.callPackage ./my-stenv-adapter.nix {};
in rec {
    # Use this `stdenv` for packages you want to be picked from the official caches - i.e. don't want
    # to rebuild yourself
    upstream = unoptimizedPkgs.stdenv;

    reallySafeTweaks = stenvAdapter.wrapStdenv {
        inherit baseStdenv;
        extraCFlagsCompile = [
            optimizationParameter "-march=${cpuNameCc}" "-mtune=${cpuNameCc}"
            ];
        # TODO: Do we want to also change `libc`?
    };

    # Has optimizations which are typically safe to do (-O3, -march, -mtune) etc
    safeTweaks = stenvAdapter.wrapStdenv {
        baseStdenv = reallySafeTweaks;
        extraCFlagsCompile = [
            "-fomit-frame-pointer" "-fipa-icf" "-pipe"
            "-DNDEBUG"
            ];
        extraLdFlags = [ "--as-needed" "--gc-sections" ];
        extraHardeningDisable = [ "fortify" ]; # TODO: Parameter mot yet picked up properly

        # TODO: Do we want to also change `libc`?
    };

    # Enabling link-time-optimizations will break several packages. It can be beneficial for selected packages, though.
    withLto = stenvAdapter.wrapStdenv {
       baseStdenv = safeTweaks;
       extraCFlagsCompile = [
           ltoEnabledParam # --lto=auto (or --lto=thin)
           ];
     };

    # Doing fast-math will only have an impact on a few packages. Enabling it globally would easily break stuff
    withAggressiveFastMath = stenvAdapter.wrapStdenv {
         baseStdenv = safeTweaks;
         extraCFlagsCompile = [
             "-ffast-math"
             ];
         # TODO: Do we want to also change `libc`?
     };
}