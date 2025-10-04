{ optimizedPlatform, unoptimizedPkgs, optimizationParameter ? "-O3" }:
(final: prev: rec {
    # Need to compile-in LLVM into the systems ghc as it doesn't have this enabled by default and
    # some optimizations only seem to be available through LLVM
    ghcWithLlvm = ((unoptimizedPkgs.ghc)  # (unoptimizedPkgs.haskell.compiler.ghcHEAD)
        .override {
            useLLVM = true;
            # buildTargetLlvmPackages = false;
        });

    ghc =
        let
            llvmFlags = [
                "-mcpu=${optimizedPlatform.platform.gcc.tune}"
                "-enable-unsafe-fp-math" # TODO: Add flags for this!
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
})