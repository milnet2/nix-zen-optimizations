#!/usr/bin/env python3
import json
import math
import sys
import time

try:
    import numpy as np
except Exception as e:
    print(json.dumps({
        "engine": {"name": "Python", "version": sys.version.split()[0]},
        "error": f"Failed to import numpy: {e}"}), file=sys.stdout)
    sys.exit(1)


def init_matrix(rows: int, cols: int, seed: int) -> np.ndarray:
    # Deterministic low-overhead LCG similar to C/Fortran examples
    x = seed if seed != 0 else 1
    total = rows * cols
    out = np.empty((rows, cols), dtype=np.float32)
    # Fill row-major, but NumPy is C-order by default; BLAS expects Fortran-order.
    # We'll allocate Fortran-order arrays later; use a temporary 1D view here and reshape.
    buf = out.ravel()
    for i in range(total):
        x = (1664525 * x + 1013904223) & 0x7FFFFFFF  # keep it positive 31-bit
        buf[i] = ((x >> 8) & 0xFFFF) / 32768.0 - 1.0
    return out


def checksum(arr: np.ndarray) -> float:
    # Accumulate in float64 for stability, return float32-like value to match others
    s = float(np.sum(arr, dtype=np.float64))
    return s


def print_json(engine_name: str, engine_version: str, M: int, N: int, K: int, repeats: int,
               error: str | None, secs: float | None, csum: float | None) -> None:
    bytes_per = 4  # float32
    szA = M * K * bytes_per
    szB = K * N * bytes_per
    szC = M * N * bytes_per
    total_bytes = szA + szB + szC
    total_mb = total_bytes / (1024.0 * 1024.0)

    obj = {
        "engine": {"name": engine_name}
    }
    if engine_version:
        obj["engine"]["version"] = engine_version

    obj["input"] = {
        "M": M,
        "N": N,
        "K": K,
        "repeats": repeats,
        "expected_bytes_total": int(total_bytes),
        "expected_megabytes_total": round(total_mb, 1),
    }

    if error:
        obj["error"] = error

    if secs is not None and secs > 0.0:
        gflops = (2.0 * float(M) * float(N) * float(K) * float(repeats)) / (secs * 1.0e9)
        obj["output"] = {
            "time_sec": float(f"{secs:.6f}"),
            "gflops": float(f"{gflops:.2f}"),
            "checksum": float(f"{(csum or 0.0):.6f}")
        }

    json.dump(obj, sys.stdout)
    sys.stdout.write("\n")


def main(argv: list[str]) -> int:
    N = int(argv[1]) if len(argv) > 1 else 2048
    K = int(argv[2]) if len(argv) > 2 else 2048
    repeats = int(argv[3]) if len(argv) > 3 else 50

    if N <= 0 or K <= 0 or repeats <= 0:
        print("Usage: blas-test [N] [K] [repeats]", file=sys.stderr)
        return 1

    M = N

    # Create Fortran-contiguous arrays so NumPy/BLAS can use SGEMM efficiently
    A = np.asfortranarray(init_matrix(M, K, 1), dtype=np.float32)
    B = np.asfortranarray(init_matrix(K, N, 2), dtype=np.float32)
    C = np.asfortranarray(np.zeros((M, N), dtype=np.float32))

    engine_name = "NumPy"
    engine_version = getattr(np, "__version__", "")

    # Warmup
    np.matmul(A, B, out=C)

    t0 = time.perf_counter()
    for _ in range(repeats):
        np.matmul(A, B, out=C)
    t1 = time.perf_counter()

    secs = t1 - t0
    csum = checksum(C)

    print_json(engine_name, engine_version, M, N, K, repeats, None, secs, csum)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
