{ optimizedPlatform, unoptimizedPkgs, isLtoEnabled ? false, optimizationParameter ? "-O3" }:
(final: prev: rec {
    rustc = prev.symlinkJoin {
       name = "rustc-${optimizedPlatform.platform.gcc.tune}";
       paths = [ unoptimizedPkgs.rustc ];
       buildInputs = [ unoptimizedPkgs.makeWrapper ];
       postBuild = ''
           wrapProgram $out/bin/rustc \
               --add-flags "-C target-cpu=${optimizedPlatform.platform.gcc.tune} ${if isLtoEnabled then "-C lto=${optimizedPlatform.platform.rust.lto}" else ""} -C codegen-units=1"
       '';
    } // {
        inherit (unoptimizedPkgs.rustc) badTargetPlatforms;
        meta = unoptimizedPkgs.rustc.meta // {
            platforms = unoptimizedPkgs.rustc.meta.platforms ++ optimizedPlatform.platform; };
        targetPlatforms = [ optimizedPlatform.platform ];
    };

    cargo = prev.symlinkJoin {
        # https://search.nixos.org/packages?channel=unstable&show=cargo&query=cargo
        name = "cargo-${optimizedPlatform.platform.gcc.tune}";
        paths = [ unoptimizedPkgs.cargo ];
        buildInputs = [ unoptimizedPkgs.makeWrapper ];
        postBuild = ''
            wrapProgram $out/bin/cargo \
                --set NIX_RUSTFLAGS "-C target-cpu=${optimizedPlatform.platform.gcc.tune} ${if isLtoEnabled then "-C lto=${optimizedPlatform.platform.rust.lto}" else ""}  -C codegen-units=1"
        '';
    } // {
        inherit (prev.cargo) badTargetPlatforms;
        meta = unoptimizedPkgs.cargo.meta // {
            platforms = rustc.meta.platforms; };
        targetPlatforms = [ optimizedPlatform.platform ];
    };
})