{-# LANGUAGE CPP #-}
-- buildinfo-haskell: prints compiler/target info as JSON
-- Uses CPP so we can inject feature macros similarly to C/C++ tests.

module Main where

import System.Info (compilerName, compilerVersion)
import Data.Version (showVersion)
import Data.List (intercalate)
import System.IO (hPutStrLn, stderr)

jsonString :: String -> String
jsonString s = "\"" ++ concatMap esc s ++ "\""
  where
    esc '"'  = "\\\""
    esc '\\' = "\\\\"
    esc c     = [c]

kvStr :: String -> String -> String
kvStr k v = jsonString k ++ ": " ++ jsonString v

kvBool :: String -> Bool -> String
kvBool k v = jsonString k ++ ": " ++ if v then "true" else "false"

#ifdef __FAST_MATH__
fastMath :: Bool
fastMath = True
#else
fastMath :: Bool
fastMath = False
#endif

-- SIMD feature flags detected via CPP macros (injected at compile time)
#ifdef __SSE__
hasSSE :: Bool
hasSSE = True
#else
hasSSE :: Bool
hasSSE = False
#endif

#ifdef __SSE2__
hasSSE2 :: Bool
hasSSE2 = True
#else
hasSSE2 :: Bool
hasSSE2 = False
#endif

#ifdef __SSE3__
hasSSE3 :: Bool
hasSSE3 = True
#else
hasSSE3 :: Bool
hasSSE3 = False
#endif

#ifdef __SSSE3__
hasSSSE3 :: Bool
hasSSSE3 = True
#else
hasSSSE3 :: Bool
hasSSSE3 = False
#endif

#ifdef __SSE4_1__
hasSSE41 :: Bool
hasSSE41 = True
#else
hasSSE41 :: Bool
hasSSE41 = False
#endif

#ifdef __SSE4_2__
hasSSE42 :: Bool
hasSSE42 = True
#else
hasSSE42 :: Bool
hasSSE42 = False
#endif

#ifdef __AVX__
hasAVX :: Bool
hasAVX = True
#else
hasAVX :: Bool
hasAVX = False
#endif

#ifdef __AVX2__
hasAVX2 :: Bool
hasAVX2 = True
#else
hasAVX2 :: Bool
hasAVX2 = False
#endif

#ifdef __AVX512F__
hasAVX512F :: Bool
hasAVX512F = True
#else
hasAVX512F :: Bool
hasAVX512F = False
#endif
#ifdef __AVX512CD__
hasAVX512CD :: Bool
hasAVX512CD = True
#else
hasAVX512CD :: Bool
hasAVX512CD = False
#endif
#ifdef __AVX512ER__
hasAVX512ER :: Bool
hasAVX512ER = True
#else
hasAVX512ER :: Bool
hasAVX512ER = False
#endif
#ifdef __AVX512PF__
hasAVX512PF :: Bool
hasAVX512PF = True
#else
hasAVX512PF :: Bool
hasAVX512PF = False
#endif
#ifdef __AVX512BW__
hasAVX512BW :: Bool
hasAVX512BW = True
#else
hasAVX512BW :: Bool
hasAVX512BW = False
#endif
#ifdef __AVX512DQ__
hasAVX512DQ :: Bool
hasAVX512DQ = True
#else
hasAVX512DQ :: Bool
hasAVX512DQ = False
#endif
#ifdef __AVX512VL__
hasAVX512VL :: Bool
hasAVX512VL = True
#else
hasAVX512VL :: Bool
hasAVX512VL = False
#endif
#ifdef __AVX512IFMA__
hasAVX512IFMA :: Bool
hasAVX512IFMA = True
#else
hasAVX512IFMA :: Bool
hasAVX512IFMA = False
#endif
#ifdef __AVX512VBMI__
hasAVX512VBMI :: Bool
hasAVX512VBMI = True
#else
hasAVX512VBMI :: Bool
hasAVX512VBMI = False
#endif
#ifdef __AVX512VNNI__
hasAVX512VNNI :: Bool
hasAVX512VNNI = True
#else
hasAVX512VNNI :: Bool
hasAVX512VNNI = False
#endif

-- target arch
#ifdef __x86_64__
archStr :: String
archStr = "x86_64"
#elif defined(__aarch64__)
archStr :: String
archStr = "aarch64"
#else
archStr :: String
archStr = "unknown"
#endif

main :: IO ()
main = do
  let versionStr = compilerName ++ " " ++ showVersion compilerVersion
      compilerFields =
        [ kvStr "version_string" versionStr
        , kvBool "fast_math" fastMath
        ] ++
        [ kvBool "sse" hasSSE
        , kvBool "sse2" hasSSE2
        , kvBool "sse3" hasSSE3
        , kvBool "ssse3" hasSSSE3
        , kvBool "sse4_1" hasSSE41
        , kvBool "sse4_2" hasSSE42
        , kvBool "avx" hasAVX
        , kvBool "avx2" hasAVX2
        , kvBool "avx512f" hasAVX512F
        , kvBool "avx512cd" hasAVX512CD
        , kvBool "avx512er" hasAVX512ER
        , kvBool "avx512pf" hasAVX512PF
        , kvBool "avx512bw" hasAVX512BW
        , kvBool "avx512dq" hasAVX512DQ
        , kvBool "avx512vl" hasAVX512VL
        , kvBool "avx512ifma" hasAVX512IFMA
        , kvBool "avx512vbmi" hasAVX512VBMI
        , kvBool "avx512vnni" hasAVX512VNNI
        ]
      compilerObj = "\n\t\"compiler\": {\n\t\t" ++ intercalate ",\n\t\t" compilerFields ++ "\n\t}"
      targetObj = "\n\t\"target\": {\n\t\t" ++ kvStr "arch" archStr ++ "\n\t}"
      json = "{" ++ compilerObj ++ "," ++ targetObj ++ "\n}"
  putStrLn json
