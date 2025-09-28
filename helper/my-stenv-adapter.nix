# Helper functions similar to `pkgs.stdenvAdapters` to wrap `stenv`.
# See: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/stdenv/adapters.nix
# See also (more tricky): https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/build-support/cc-wrapper/default.nix
{ pkgs, lib ? pkgs.lib }:
{
    wrapStdenv = {
        baseStdenv, # The env to wrap
        isLocalNativeBuilds ? false, # Set -march=native and other related flags

        extraCFlagsCompile ? [], # Appended to env NIX_CFLAGS_COMPILE
        extraCFlagsLink ? [], # Appended to env NIX_CFLAGS_LINK - TODO: Unused
        extraCPPFlagsCompile ? [], # Appended to NIX_CPPFLAGS_COMPILE - TODO: Unused
        extraLdFlags ? [], # Appended to NIX_LDFLAGS

        # TODO: NIX_RUSTFLAGS

        extraHardeningDisable ? [], # Appended to NIX_HARDENING_DISABLE - TODO: Unused - https://blog.mayflower.de/5800-Hardening-Compiler-Flags-for-NixOS.html
    }:
        assert lib.assertMsg (! builtins.elem "-march=native" extraCFlagsCompile)
            "Use the parameter `isLocalNativeBuilds = true` instead of using -march=native";
        assert lib.assertMsg (! builtins.elem "-mcpu=native" extraCFlagsCompile)
            "Use the parameter `isLocalNativeBuilds = true` instead of using -mcpu=native";

        lib.pipe baseStdenv [
            (se: pkgs.stdenvAdapters.withCFlags (extraCFlagsCompile ++ builtins.map (ldFlag: "-Wl,${ldFlag}") extraLdFlags) se)
            (se: pkgs.stdenvAdapters.withDefaultHardeningFlags [] se) # TODO: Do this properly
            (se: if (isLocalNativeBuilds) then (pkgs.stdenvAdapters.impureUseNativeOptimizations se) else se)
        ];
}