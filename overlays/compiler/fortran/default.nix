{ optimizedPlatform }:
(final: prev: {
    gfortran = prev.symlinkJoin {
        name = "gfortran-${optimizedPlatform.platform.gcc.tune}";
        paths = [ prev.gfortran ];
        buildInputs = [ prev.makeWrapper ];
        # Classic Fortran flags; projects pick up FFLAGS/FCFLAGS, and Nix’s generic builder
        # respects NIX_FFLAGS_COMPILE similarly to NIX_CFLAGS_COMPILE.
        postBuild = ''
          wrapProgram $out/bin/gfortran \
            --set-default FFLAGS   "-O3 -pipe -fomit-frame-pointer -march=${optimizedPlatform.platform.gcc.arch} -mtune=${optimizedPlatform.platform.gcc.tune}" \
            --set-default FCFLAGS  "-O3 -pipe -fomit-frame-pointer -march=${optimizedPlatform.platform.gcc.arch} -mtune=${optimizedPlatform.platform.gcc.tune}" \
            --set-default NIX_FFLAGS_COMPILE "-O3 -pipe -fomit-frame-pointer -march=${optimizedPlatform.platform.gcc.arch} -mtune=${optimizedPlatform.platform.gcc.tune}"
        '';
   };
})