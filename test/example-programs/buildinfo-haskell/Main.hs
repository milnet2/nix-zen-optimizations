module Main where

-- Information about the optimizations is only available from LLVM which only comes after
-- the evaluation of Haskell. So we cant output it from here.

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

#ifdef x86_64_HOST_ARCH
archStr :: String
archStr = "x86_64"
#elif defined(aarch64_HOST_ARCH)
archStr :: String
archStr = "aarch64"
#else
archStr :: String
archStr = "unknown"
#endif

main :: IO ()
main = do
  let versionStr = compilerName ++ " " ++ showVersion compilerVersion
--      compilerFields =
--        [ kvStr "version_string" versionStr
--        , kvBool "fast_math" fastMath
--        ] ++
--        [ kvBool "sse" hasSSE
--        , kvBool "sse2" hasSSE2
--        , kvBool "sse3" hasSSE3
--        , kvBool "ssse3" hasSSSE3
--        , kvBool "sse4_1" hasSSE41
--        , kvBool "sse4_2" hasSSE42
--        , kvBool "avx" hasAVX
--        , kvBool "avx2" hasAVX2
--        , kvBool "avx512f" hasAVX512F
--        , kvBool "avx512cd" hasAVX512CD
--        , kvBool "avx512er" hasAVX512ER
--        , kvBool "avx512pf" hasAVX512PF
--        , kvBool "avx512bw" hasAVX512BW
--        , kvBool "avx512dq" hasAVX512DQ
--        , kvBool "avx512vl" hasAVX512VL
--        , kvBool "avx512ifma" hasAVX512IFMA
--        , kvBool "avx512vbmi" hasAVX512VBMI
--        , kvBool "avx512vnni" hasAVX512VNNI
--        ]
      compilerObj = "\n\t\"compiler\": {\n\t\t" ++ intercalate ",\n\t\t" [] ++ "\n\t}"
      targetObj = "\n\t\"target\": {\n\t\t" ++ kvStr "arch" archStr ++ "\n\t}"
      json = "{" ++ compilerObj ++ "," ++ targetObj ++ "\n}"
  putStrLn json
