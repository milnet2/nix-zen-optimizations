#!/usr/bin/env Rscript
# Emit JSON build info for R similar to other language tests

# Read CPU flags from /proc/cpuinfo (Linux)
read_cpu_flags <- function() {
  flags <- character()
  if (file.exists("/proc/cpuinfo")) {
    lines <- readLines("/proc/cpuinfo", warn = FALSE)
    # Find the first 'flags' line
    idx <- grep("^flags\\s*: ", lines)
    if (length(idx) > 0) {
      flag_line <- sub("^flags\\s*: ", "", lines[idx[1]])
      flags <- strsplit(flag_line, " ")[[1]]
    }
  }
  unique(flags)
}

has_flag <- function(flags, name) {
  name %in% flags
}

flags <- read_cpu_flags()

# Feature mapping from /proc/cpuinfo names
sse       <- has_flag(flags, "sse")
sse2      <- has_flag(flags, "sse2")
sse3      <- has_flag(flags, "sse3")
ssse3     <- has_flag(flags, "ssse3")
sse4_1    <- has_flag(flags, "sse4_1")
sse4_2    <- has_flag(flags, "sse4_2")
avx       <- has_flag(flags, "avx")
avx2      <- has_flag(flags, "avx2")
# AVX-512 flags
avx512f   <- has_flag(flags, "avx512f")
avx512cd  <- has_flag(flags, "avx512cd")
avx512er  <- has_flag(flags, "avx512er")
avx512pf  <- has_flag(flags, "avx512pf")
avx512bw  <- has_flag(flags, "avx512bw")
avx512dq  <- has_flag(flags, "avx512dq")
avx512vl  <- has_flag(flags, "avx512vl")
avx512ifma<- has_flag(flags, "avx512ifma")
avx512vbmi<- has_flag(flags, "avx512vbmi")
avx512vnni<- has_flag(flags, "avx512vnni")

arch <- R.version$arch # e.g., x86_64
# R.version$arch may be like "x86_64"; ensure consistent
arch <- sub("-.*$", "", arch)
version_string <- paste0(R.version$major, ".", R.version$minor)

# Helper to convert booleans to JSON true/false strings
booljson <- function(x) if (isTRUE(x)) "true" else "false"

json <- paste0(
  "{",
  "\"target\":{\"arch\":\"", arch, "\"}",
  ",\"compiler\":{",
    "\"version_string\":\"", version_string, "\"",
    ",\"fast_math\":true",
    ",\"sse\":", booljson(sse),
    ",\"sse2\":", booljson(sse2),
    ",\"sse3\":", booljson(sse3),
    ",\"ssse3\":", booljson(ssse3),
    ",\"sse4_1\":", booljson(sse4_1),
    ",\"sse4_2\":", booljson(sse4_2),
    ",\"avx\":", booljson(avx),
    ",\"avx2\":", booljson(avx2),
    ",\"avx512f\":", booljson(avx512f),
    ",\"avx512cd\":", booljson(avx512cd),
    ",\"avx512er\":", booljson(avx512er),
    ",\"avx512pf\":", booljson(avx512pf),
    ",\"avx512bw\":", booljson(avx512bw),
    ",\"avx512dq\":", booljson(avx512dq),
    ",\"avx512vl\":", booljson(avx512vl),
    ",\"avx512ifma\":", booljson(avx512ifma),
    ",\"avx512vbmi\":", booljson(avx512vbmi),
    ",\"avx512vnni\":", booljson(avx512vnni),
  "}",
  "}"
)

cat(json, "\n")
