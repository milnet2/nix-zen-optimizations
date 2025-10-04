{ optimizedPlatform, unoptimizedPkgs }:
(final: prev: rec {
    R = (prev.R.override {
        inherit (unoptimizedPkgs)
            perl ncurses curl readline texinfo bison jdk tzdata
            texlive texliveSmall graphviz pango
            libtiff libjpeg;
        libX11 = noOptimizePkgs.xorg.libX11;
        libXt = noOptimizePkgs.xorg.libXt;
        inherit (final) blas lapack;

        inherit (unoptimizedPkgs) stdenv gfortran; # TODO Because of LTO - TODO: Optimized? - match GCC version
    })
    .overrideAttrs (old: {
        doCheck = false; # TODO: These have different flags in grDevices-Ex
#        env = (old.env or {}) // {
#            # Try to avoid test flakyness
#            OMP_NUM_THREADS        = "1";
#            OPENBLAS_NUM_THREADS   = "1";
#            BLIS_NUM_THREADS       = "1";
#            GOTO_NUM_THREADS       = "1";
#            VECLIB_MAXIMUM_THREADS = "1";
#            MKL_NUM_THREADS        = "1";
#        };
      })
     ;

})