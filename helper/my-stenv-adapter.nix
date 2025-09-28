# Helper functions similar to `pkgs.stdenvAdapters` to wrap `stenv`.
# See: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/stdenv/adapters.nix
# See also (more tricky): https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/build-support/cc-wrapper/default.nix
{ pkgs }:
{
    wrapStdenv = {
        baseStdenv, # The env to wrap
        extraCFlagsCompile ? [], # Appended to env NIX_CFLAGS_COMPILE
        extraCFlagsLink ? [], # Appended to env NIX_CFLAGS_LINK
        extraCPPFlagsCompile ? [], # Appended to NIX_CPPFLAGS_COMPILE
        extraLdFlags ? [], # Appended to NIX_LDFLAGS

        # TODO: NIX_RUSTFLAGS

        extraHardeningDisable ? [], # Appended to NIX_HARDENING_DISABLE
    }:
        #pkgs.stdenvAdapters.impureUseNativeOptimizations # TODO??
        pkgs.stdenvAdapters.withCFlags (extraCFlagsCompile ++ builtins.map (ldFlag: "-Wl,${ldFlag}") extraLdFlags)
        # See: https://blog.mayflower.de/5800-Hardening-Compiler-Flags-for-NixOS.html
        (pkgs.stdenvAdapters.withDefaultHardeningFlags []
#        (pkgs.stdenvAdapters.addAttrsToDerivation { # TODO: How to set these?
#            NIX_CFLAGS_LINK = toString extraCFlagsLink;
#            NIX_CPPFLAGS_COMPILE = toString extraCPPFlagsCompile;
#            NIX_LDFLAGS = toString extraLdFlags;
#
#            NIX_HARDENING_DISABLE = toString extraHardeningDisable;
#        }
        baseStdenv);
}