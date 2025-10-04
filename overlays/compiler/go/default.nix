{ optimizedPlatform, unoptimizedPkgs, isLtoEnabled ? false, optimizationParameter ? "-O3" }:
(final: prev: rec {
    go = prev.symlinkJoin {
       # https://search.nixos.org/packages?channel=unstable&show=go&query=go
       name = "go-${optimizedPlatform.platform.go.GOARCH}-${optimizedPlatform.platform.go.GOAMD64}";
       paths = [ unoptimizedPkgs.go ];
       buildInputs = [ unoptimizedPkgs.makeWrapper ];
       # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/setup-hooks/make-wrapper.sh
       postBuild = ''
           wrapProgram $out/bin/go \
                --set GOOS "${optimizedPlatform.platform.go.GOOS}" \
                --set GOARCH "${optimizedPlatform.platform.go.GOARCH}" \
                --set GOAMD64 "${optimizedPlatform.platform.go.GOAMD64}" \
                --set-default CGO_CFLAGS "${optimizationParameter} -fomit-frame-pointer -ffast-math -march=${optimizedPlatform.platform.gcc.arch} -mtune=${optimizedPlatform.platform.gcc.tune} ${if isLtoEnabled then "-flto=auto" else ""} -fipa-icf" \
                --set-default CGO_LDFLAGS "--as-needed --gc-sections"
           '';
    } // {
        inherit (unoptimizedPkgs.go) badTargetPlatforms CGO_ENABLED;
        GOOS = optimizedPlatform.platform.go.GOOS;
        GOARCH = optimizedPlatform.platform.go.GOARCH;
        GOAMD64 = optimizedPlatform.platform.go.GOAMD64;
        meta = unoptimizedPkgs.go.meta // {
            platforms = [ optimizedPlatform.platform ]; };
    };

    buildGoModule = prev.buildGoModule.override {
        # https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/go/module.nix
        inherit go;
    };
})