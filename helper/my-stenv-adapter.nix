# Helper functions similar to `pkgs.stdenvAdapters` to wrap `stenv`.
# See: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/stdenv/adapters.nix
# See also (more tricky): https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/build-support/cc-wrapper/default.nix
{ pkgs }:
let
    # Copy of "private" function in `pkgs.stdenvAdapters`
    # See: https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/pkgs/stdenv/adapters.nix#L15
    # TODO: defaultMkDerivationFromStdenv = stdenv: (import ./generic/make-derivation.nix { inherit lib config; } stdenv).mkDerivation;
    defaultMkDerivationFromStdenv = stdenv: stdenv.mkDerivation;

    # Copy of "private" function in `pkgs.stdenvAdapters`
    # See: https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/pkgs/stdenv/adapters.nix#L23
    withOldMkDerivation = stdenvSuperArgs: k: stdenvSelf:
        let
            mkDerivationFromStdenv-super =
                stdenvSuperArgs.mkDerivationFromStdenv or defaultMkDerivationFromStdenv;
            mkDerivationSuper = mkDerivationFromStdenv-super stdenvSelf;
        in
            k stdenvSelf mkDerivationSuper;

    # Copy of "private" function in `pkgs.stdenvAdapters`
    # See: https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/pkgs/stdenv/adapters.nix#L33
    extendMkDerivationArgs = old: f:
        withOldMkDerivation old (
            _: mkDerivationSuper: args:
            (mkDerivationSuper args).overrideAttrs f
        );

    # Copy of "private" function in `pkgs.stdenvAdapters`
    # See: https://github.com/NixOS/nixpkgs/blob/e643668fd71b949c53f8626614b21ff71a07379d/pkgs/stdenv/adapters.nix#L41
    overrideMkDerivationResult = old: f:
        withOldMkDerivation old (
            _: mkDerivationSuper: args:
            f (mkDerivationSuper args));
in rec {
    wrapStenv = {
        baseStdenv, # The env to wrap
        extraCFlagsCompile ? [], # Appended to env NIX_CFLAGS_COMPILE
        extraCFlagsLink ? [], # Appended to env NIX_CFLAGS_LINK
        extraCPPFlagsCompile ? [], # Appended to NIX_CPPFLAGS_COMPILE
        extraLdFlags ? [], # Appended to NIX_LDFLAGS

        # TODO: NIX_RUSTFLAGS

        extraHardeningDisable ? [], # Appended to NIX_HARDENING_DISABLE
    }:
        #pkgs.stdenvAdapters.impureUseNativeOptimizations # TODO??
        pkgs.stdenvAdapters.withCFlags extraCFlagsCompile
        (pkgs.stdenvAdapters.withDefaultHardeningFlags []
#        (pkgs.stdenvAdapters.addAttrsToDerivation { # TODO: How to set these?
#            NIX_CFLAGS_LINK = toString extraCFlagsLink;
#            NIX_CPPFLAGS_COMPILE = toString extraCPPFlagsCompile;
#            NIX_LDFLAGS = toString extraLdFlags;
#
#            NIX_HARDENING_DISABLE = toString extraHardeningDisable;
#        }
        baseStdenv);

#        baseStdenv.override (old: {
#            mkDerivationFromStdenv = extendMkDerivationArgs old (args: { env = (args.env or { }) // {
#                NIX_CFLAGS_COMPILE = toString (args.env.NIX_CFLAGS_COMPILE or "") + " ${toString extraCFlagsCompile}";
#                NIX_CFLAGS_LINK = toString (args.env.NIX_CFLAGS_LINK or "") + " ${toString extraCFlagsLink}";
#                NIX_CPPFLAGS_COMPILE = toString (args.env.NIX_CPPFLAGS_COMPILE or "") + " ${toString extraCPPFlagsCompile}";
#                NIX_LDFLAGS = toString (args.env.NIX_LDFLAGS or "") + " ${toString extraLdFlags}";
#
#                NIX_HARDENING_DISABLE = toString (args.env.NIX_HARDENING_DISABLE or "") + " ${toString extraHardeningDisable}";
#            };});});

}