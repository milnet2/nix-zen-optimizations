#!/usr/bin/env julia
# Emit JSON build info for Julia similar to other language tests

# No external dependencies; print JSON manually

function cpu_feat(name::Symbol)
    try
        return Base.cpu_feature(name) === true
    catch
        return false
    end
end

# Helper to render booleans
booljson(x::Bool) = x ? "true" : "false"

# Collect features
sse       = cpu_feat(:sse)
sse2      = cpu_feat(:sse2)
sse3      = cpu_feat(:sse3)
ssse3     = cpu_feat(:ssse3)
sse4_1    = cpu_feat(:sse4_1)
sse4_2    = cpu_feat(:sse4_2)
avx       = cpu_feat(:avx)
avx2      = cpu_feat(:avx2)
avx512f   = cpu_feat(:avx512f)
avx512cd  = cpu_feat(:avx512cd)
avx512er  = cpu_feat(:avx512er)
avx512pf  = cpu_feat(:avx512pf)
avx512bw  = cpu_feat(:avx512bw)
avx512dq  = cpu_feat(:avx512dq)
avx512vl  = cpu_feat(:avx512vl)
avx512ifma= cpu_feat(:avx512ifma)
avx512vbmi= cpu_feat(:avx512vbmi)
avx512vnni= cpu_feat(:avx512vnni)

arch = String(Sys.ARCH)
ver = string(VERSION)

# Print JSON
println("{" *
        "\"target\":{\"arch\":\"$arch\"}," *
        "\"compiler\":{" *
          "\"version_string\":\"$ver\"," *
          "\"fast_math\":true," *
          "\"sse\":" * booljson(sse) * "," *
          "\"sse2\":" * booljson(sse2) * "," *
          "\"sse3\":" * booljson(sse3) * "," *
          "\"ssse3\":" * booljson(ssse3) * "," *
          "\"sse4_1\":" * booljson(sse4_1) * "," *
          "\"sse4_2\":" * booljson(sse4_2) * "," *
          "\"avx\":" * booljson(avx) * "," *
          "\"avx2\":" * booljson(avx2) * "," *
          "\"avx512f\":" * booljson(avx512f) * "," *
          "\"avx512cd\":" * booljson(avx512cd) * "," *
          "\"avx512er\":" * booljson(avx512er) * "," *
          "\"avx512pf\":" * booljson(avx512pf) * "," *
          "\"avx512bw\":" * booljson(avx512bw) * "," *
          "\"avx512dq\":" * booljson(avx512dq) * "," *
          "\"avx512vl\":" * booljson(avx512vl) * "," *
          "\"avx512ifma\":" * booljson(avx512ifma) * "," *
          "\"avx512vbmi\":" * booljson(avx512vbmi) * "," *
          "\"avx512vnni\":" * booljson(avx512vnni) *
        "}" *
      "}")
