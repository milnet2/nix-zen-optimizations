#!/usr/bin/env python3
import json
import math
import sys
import time
import os
import argparse

try:
    import numpy as np
except Exception as e:
    print(json.dumps({
        "engine": {"name": "Python", "version": sys.version.split()[0]},
        "error": f"Failed to import numpy: {e}"}), file=sys.stdout)
    sys.exit(1)

# Optional GPU backend via PyTorch (CUDA/ROCm). We import lazily and
# only use it if requested and available.
try:
    import torch  # type: ignore
except Exception:
    torch = None  # sentinel; handled at runtime


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


def checksum_np(arr: np.ndarray) -> float:
    # Accumulate in float64 for stability
    return float(np.sum(arr, dtype=np.float64))


def checksum_torch(t: "torch.Tensor") -> float:
    # Sum on device, then transfer scalar to host as float
    if torch is None:
        raise RuntimeError("Torch backend requested but torch not available")
    return float(t.sum(dtype=t.dtype).detach().cpu().item())


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
    parser = argparse.ArgumentParser(description="BLAS SGEMM benchmark (Python)")
    parser.add_argument("N", nargs="?", type=int, default=2048)
    parser.add_argument("K", nargs="?", type=int, default=2048)
    parser.add_argument("repeats", nargs="?", type=int, default=50)
    parser.add_argument("--backend", choices=["auto", "cpu", "gpu"], default=os.environ.get("BLAS_BACKEND", "auto"))
    args = parser.parse_args(argv[1:])

    N = args.N
    K = args.K
    repeats = args.repeats

    if N <= 0 or K <= 0 or repeats <= 0:
        print("Usage: blas-test [N] [K] [repeats]", file=sys.stderr)
        return 1

    M = N

    # CPU path (NumPy/BLAS)
    def run_cpu():
        A = np.asfortranarray(init_matrix(M, K, 1), dtype=np.float32)
        B = np.asfortranarray(init_matrix(K, N, 2), dtype=np.float32)
        C = np.asfortranarray(np.zeros((M, N), dtype=np.float32))
        # Warmup
        np.matmul(A, B, out=C)
        t0 = time.perf_counter()
        for _ in range(repeats):
            np.matmul(A, B, out=C)
        t1 = time.perf_counter()
        secs = t1 - t0
        csum = checksum_np(C)
        print_json("NumPy", getattr(np, "__version__", ""), M, N, K, repeats, None, secs, csum)

    # GPU path (PyTorch CUDA/ROCm)
    def run_gpu():
        if torch is None:
            print_json("PyTorch", "", M, N, K, repeats, "torch not available", None, None)
            return
        def _hip_built() -> bool:
            try:
                ver = getattr(torch, "version", None)
                return bool(getattr(ver, "hip", None))
            except Exception:
                return False
        # Determine if we can use GPU (CUDA or ROCm/HIP)
        gpu_ok = False
        if getattr(torch, "cuda", None) is not None and torch.cuda.is_available():
            gpu_ok = True
        elif _hip_built():
            # Probe by trying a tiny allocation on 'cuda' device (alias for HIP on ROCm builds)
            try:
                _ = torch.empty((1,), device=torch.device("cuda"))
                torch.cuda.synchronize()
                gpu_ok = True
            except Exception:
                gpu_ok = False
        if not gpu_ok:
            ver = getattr(torch, "__version__", "")
            cuda_ver = getattr(getattr(torch, "version", None), "cuda", None)
            hip_ver = getattr(getattr(torch, "version", None), "hip", None)
            hint = "torch.cuda not available"
            if hip_ver and not cuda_ver:
                hint = f"ROCm build detected (HIP {hip_ver}) but GPU not available; check ROCm runtime and device support"
            print_json("PyTorch", ver, M, N, K, repeats, hint, None, None)
            return
        device = torch.device("cuda")
        dtype = torch.float32
        # Prepare host arrays using same generator for determinism
        A_h = init_matrix(M, K, 1).astype(np.float32, copy=False)
        B_h = init_matrix(K, N, 2).astype(np.float32, copy=False)
        # Upload once
        A = torch.from_numpy(np.ascontiguousarray(A_h)).to(device=device, dtype=dtype)
        B = torch.from_numpy(np.ascontiguousarray(B_h)).to(device=device, dtype=dtype)
        # Output buffer
        C = torch.empty((M, N), device=device, dtype=dtype)
        # Warmup
        torch.matmul(A, B, out=C)
        torch.cuda.synchronize()
        t0 = time.perf_counter()
        for _ in range(repeats):
            torch.matmul(A, B, out=C)
        torch.cuda.synchronize()
        t1 = time.perf_counter()
        secs = t1 - t0
        csum = checksum_torch(C)
        print_json("PyTorch", getattr(torch, "__version__", ""), M, N, K, repeats, None, secs, csum)

    # Decide backend
    backend = args.backend
    if backend == "cpu":
        run_cpu()
    elif backend == "gpu":
        run_gpu()
    else:  # auto
        def _hip_built() -> bool:
            try:
                ver = getattr(torch, "version", None)
                return bool(getattr(ver, "hip", None))
            except Exception:
                return False
        def _gpu_available() -> bool:
            if torch is None:
                return False
            try:
                if getattr(torch, "cuda", None) is not None and torch.cuda.is_available():
                    return True
                # If ROCm build, try a small probe allocation on 'cuda' (alias for HIP)
                if _hip_built():
                    try:
                        dev = torch.device("cuda")
                        _ = torch.empty((1,), device=dev)
                        # synchronize exists on ROCm builds too
                        torch.cuda.synchronize()
                        return True
                    except Exception:
                        return False
            except Exception:
                return False
            return False
        if _gpu_available():
            run_gpu()
        else:
            run_cpu()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
