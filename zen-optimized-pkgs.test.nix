# Unit tests
# See: https://nix-community.github.io/nix-unit/
# nix run --no-write-lock-file github:nix-community/nix-unit -- ./zen-optimized-pkgs.test.nix
{
   importablePkgsDelegate ? <nixpkgs>,
   lib ? (import importablePkgsDelegate {}).lib,
}: let
    pkgsTuned = import ./zen-optimized-pkgs.nix {
        inherit importablePkgsDelegate lib;
        amdZenVersion = 2; # TODO: 5
        isLtoEnabled = true; };
    isAvx512Expected = false;
in {
    "Optimized C compilation" = let
        buildInfoProgram = pkgsTuned.callPackage ./test/example-programs/buildinfo-c {};
        buildInfoJson = builtins.fromJSON (builtins.readFile "${buildInfoProgram}/lib/buildinfo.json"); # Json was created by executing program
    in {
        "test target arch is x86_64" = {
            expr = buildInfoJson.target.arch;
            expected = "x86_64";
        };
        "test gcc version" = {
            expr = buildInfoJson.compiler.version_string;
            expected = pkgsTuned.stdenv.cc.version;
        };
        "test fastmath" = {
            expr = buildInfoJson.compiler.fast_math;
            expected = true;
        };
        "test avx and sse" = {
            expr = {
                sse = buildInfoJson.compiler.sse or false;
                sse2 = buildInfoJson.compiler.sse2 or false;
                sse3 = buildInfoJson.compiler.sse3 or false;
                ssse3 = buildInfoJson.compiler.ssse3 or false;
                sse4_1 = buildInfoJson.compiler.sse4_1 or false;
                sse4_2 = buildInfoJson.compiler.sse4_2 or false;

                avx = buildInfoJson.compiler.avx or false;
                avx2 = buildInfoJson.compiler.avx2 or false;
                avx512f = buildInfoJson.compiler.avx512f or false;
                avx512cd = buildInfoJson.compiler.avx512cd or false;
                avx512er = buildInfoJson.compiler.avx512er or false;
                avx512pf = buildInfoJson.compiler.avx512pf or false;
                avx512bw = buildInfoJson.compiler.avx512bw or false;
                avx512dq = buildInfoJson.compiler.avx512dq or false;
                avx512vl = buildInfoJson.compiler.avx512vl or false;
                avx512ifma = buildInfoJson.compiler.avx512ifma or false;
                avx512vbmi = buildInfoJson.compiler.avx512vbmi or false;
                avx512vnni = buildInfoJson.compiler.avx512vnni or false;
            };
            expected = {
                sse = true;
                sse2 = true;
                sse3 = true;
                ssse3 = true;
                sse4_1 = true;
                sse4_2 = true;

                avx = true;
                avx2 = true;
                avx512f = isAvx512Expected;
                avx512cd = isAvx512Expected;
                avx512er = isAvx512Expected;
                avx512pf = isAvx512Expected;
                avx512bw = isAvx512Expected;
                avx512dq = isAvx512Expected;
                avx512vl = isAvx512Expected;
                avx512ifma = isAvx512Expected;
                avx512vbmi = isAvx512Expected;
                avx512vnni = isAvx512Expected;
            };
        };
    };

    "Optimized C++ compilation" = let
        buildInfoProgram = pkgsTuned.callPackage ./test/example-programs/buildinfo-cpp {};
        buildInfoJson = builtins.fromJSON (builtins.readFile "${buildInfoProgram}/lib/buildinfo.json"); # Json was created by executing program
    in {
        "test target arch is x86_64" = {
            expr = buildInfoJson.target.arch;
            expected = "x86_64";
        };
        "test g++ version" = {
            expr = buildInfoJson.compiler.version_string;
            expected = pkgsTuned.stdenv.cc.version;
        };
        "test fastmath" = {
            expr = buildInfoJson.compiler.fast_math;
            expected = true;
        };
        "test cpp version" = {
            expr = buildInfoJson.compiler.cpp_version > 0;
            expected = true;
        };
        "test avx and sse" = {
            expr = {
                sse = buildInfoJson.compiler.sse or false;
                sse2 = buildInfoJson.compiler.sse2 or false;
                sse3 = buildInfoJson.compiler.sse3 or false;
                ssse3 = buildInfoJson.compiler.ssse3 or false;
                sse4_1 = buildInfoJson.compiler.sse4_1 or false;
                sse4_2 = buildInfoJson.compiler.sse4_2 or false;

                avx = buildInfoJson.compiler.avx or false;
                avx2 = buildInfoJson.compiler.avx2 or false;
                avx512f = buildInfoJson.compiler.avx512f or false;
                avx512cd = buildInfoJson.compiler.avx512cd or false;
                avx512er = buildInfoJson.compiler.avx512er or false;
                avx512pf = buildInfoJson.compiler.avx512pf or false;
                avx512bw = buildInfoJson.compiler.avx512bw or false;
                avx512dq = buildInfoJson.compiler.avx512dq or false;
                avx512vl = buildInfoJson.compiler.avx512vl or false;
                avx512ifma = buildInfoJson.compiler.avx512ifma or false;
                avx512vbmi = buildInfoJson.compiler.avx512vbmi or false;
                avx512vnni = buildInfoJson.compiler.avx512vnni or false;
            };
            expected = {
                sse = true;
                sse2 = true;
                sse3 = true;
                ssse3 = true;
                sse4_1 = true;
                sse4_2 = true;

                avx = true;
                avx2 = true;
                avx512f = isAvx512Expected;
                avx512cd = isAvx512Expected;
                avx512er = isAvx512Expected;
                avx512pf = isAvx512Expected;
                avx512bw = isAvx512Expected;
                avx512dq = isAvx512Expected;
                avx512vl = isAvx512Expected;
                avx512ifma = isAvx512Expected;
                avx512vbmi = isAvx512Expected;
                avx512vnni = isAvx512Expected;
            };
        };
    };

    "Go environment" =
        import ./test/test-go.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };

    "Optimized Fortran compilation" = let
        buildInfoProgram = pkgsTuned.callPackage ./test/example-programs/buildinfo-fortran {};
        buildInfoJson = builtins.fromJSON (builtins.readFile "${buildInfoProgram}/lib/buildinfo.json");
    in {
        "test target arch is x86_64" = {
            expr = buildInfoJson.target.arch;
            expected = "x86_64";
        };
        "test gfortran/gcc version" = {
            expr = builtins.match "[0-9]+\\.[0-9]+(\\.[0-9]+)?" buildInfoJson.compiler.version_string != null;
            expected = true;
        };
        "test fastmath" = {
            expr = buildInfoJson.compiler.fast_math;
            expected = true;
        };
        "test avx and sse" = {
            expr = {
                sse = buildInfoJson.compiler.sse or false;
                sse2 = buildInfoJson.compiler.sse2 or false;
                sse3 = buildInfoJson.compiler.sse3 or false;
                ssse3 = buildInfoJson.compiler.ssse3 or false;
                sse4_1 = buildInfoJson.compiler.sse4_1 or false;
                sse4_2 = buildInfoJson.compiler.sse4_2 or false;

                avx = buildInfoJson.compiler.avx or false;
                avx2 = buildInfoJson.compiler.avx2 or false;
                avx512f = buildInfoJson.compiler.avx512f or false;
                avx512cd = buildInfoJson.compiler.avx512cd or false;
                avx512er = buildInfoJson.compiler.avx512er or false;
                avx512pf = buildInfoJson.compiler.avx512pf or false;
                avx512bw = buildInfoJson.compiler.avx512bw or false;
                avx512dq = buildInfoJson.compiler.avx512dq or false;
                avx512vl = buildInfoJson.compiler.avx512vl or false;
                avx512ifma = buildInfoJson.compiler.avx512ifma or false;
                avx512vbmi = buildInfoJson.compiler.avx512vbmi or false;
                avx512vnni = buildInfoJson.compiler.avx512vnni or false;
            };
            expected = {
                sse = true;
                sse2 = true;
                sse3 = true;
                ssse3 = true;
                sse4_1 = true;
                sse4_2 = true;

                avx = true;
                avx2 = true;
                avx512f = isAvx512Expected;
                avx512cd = isAvx512Expected;
                avx512er = isAvx512Expected;
                avx512pf = isAvx512Expected;
                avx512bw = isAvx512Expected;
                avx512dq = isAvx512Expected;
                avx512vl = isAvx512Expected;
                avx512ifma = isAvx512Expected;
                avx512vbmi = isAvx512Expected;
                avx512vnni = isAvx512Expected;
            };
        };
    };

    "Optimized Haskell compilation" =
        import ./test/test-haskell.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };

    "Python environment" =
        import ./test/test-python.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };

    "R environment" =
        import ./test/test-r.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };

    "Rust environment" =
        import ./test/test-rust.test.nix { inherit importablePkgsDelegate lib
           pkgsTuned isAvx512Expected; };
}
