# Project Guidelines – nix-zen-optimizations

This repository provides tuned Nix expressions and example programs to build and test optimized toolchains (C/C++, Fortran, Go, Haskell, Python, R, Rust) and BLAS implementations on CPU and optionally GPU (ROCm). Tests are written with nix-unit and exercised via small, deterministic programs that output JSON.

These guidelines describe the project structure, how to run builds/tests, coding conventions, and how Junie should work on issues.

## Project structure (top-level)
- zen-optimized-pkgs.nix: Entry point exposing tuned package set (pkgsTuned) used by tests.
- zen-optimized-pkgs.test.nix: Aggregated nix-unit test suite importing the language-specific tests under test/.
- test/: Test specifications and example programs.
  - test/*.test.nix: Per-language or per-area nix-unit test files.
  - test/example-programs/*: Minimal example projects used during tests.
    - buildinfo-*/: "buildinfo" programs printing compiler/interpreter info as JSON.
    - blas-c/: C BLAS benchmark (CPU and ROCm GPU backends).
    - blas-fortran/: Fortran BLAS benchmark (CPU via -lblas).
    - blas-python/: Python BLAS benchmark (CPU via NumPy; optional GPU via PyTorch CUDA/ROCm).
- docu/: Additional documentation.
- .junie/: Junie configuration and this guidelines file.

## How Junie should work on issues
- Make minimal, focused changes necessary to satisfy the issue description.
- Always maintain or improve determinism and existing JSON output formats used by tests.
- Keep the User informed using the update_status tool: share findings, an up-to-date plan, and next steps. Mark progress for each plan item.
- Prefer specialized tools in this environment (search_project, get_file_structure, open, search_replace, etc.) over generic shell commands.
- Build and run relevant tests before submitting. If adding example programs, ensure their default.nix builds and their test.nix captures result.json deterministically.

## Running tests (nix-unit)
- Run the entire suite from repository root:
  - nix run --no-write-lock-file github:nix-community/nix-unit -- --log-format bar ./zen-optimized-pkgs.test.nix
- Run individual test groups (from repository root):
  - C: nix run --no-write-lock-file github:nix-community/nix-unit -- ./test/test-c.test.nix
  - Fortran: nix run --no-write-lock-file github:nix-community/nix-unit -- ./test/test-fortran.test.nix
  - Go: nix run --no-write-lock-file github:nix-community/nix-unit -- ./test/test-go.test.nix
  - Haskell: nix run --no-write-lock-file github:nix-community/nix-unit -- ./test/test-haskell.test.nix
  - Python: nix run --no-write-lock-file github:nix-community/nix-unit -- ./test/test-python.test.nix
  - R: nix run --no-write-lock-file github:nix-community/nix-unit -- ./test/test-r.test.nix
  - Rust: nix run --no-write-lock-file github:nix-community/nix-unit -- ./test/test-rust.test.nix

Notes:
- Some BLAS GPU tests in C can be "spoofed" for unsupported GPUs via HSA_OVERRIDE_GFX_VERSION; see test/example-programs/blas-c/README.adoc.
- Python GPU path requires a ROCm/CUDA-enabled PyTorch; the Python example auto-detects ROCm and will emit a helpful error in JSON if unavailable.

## Controlling build output and logs
- nix-build tends to be very verbose. Prefer adding one or more of these flags to reduce output when running examples or builds:
  - nix-build --log-format bar ...
  - nix-build --quiet ...
  - nix-build --no-build-output ...
- If a build fails, inspect the stored build log with:
  - nix log <drv-or-out-path> | tail -n 200
  The most relevant errors are usually at the end of the log.
- nix-unit via nix run will also trigger builds and can be noisy. You can reduce output similarly:
  - nix run --quiet --no-write-lock-file github:nix-community/nix-unit -- --log-format bar ./path/to/tests.nix
  - For extremely quiet builds during tests, pre-build derivations or add --no-build-output to underlying nix operations where applicable.

## Inspecting dependencies
- To assess dependencies of a package or store path, nix-tree is useful and can emit Graphviz DOT:
  - nix run github:utdemir/nix-tree -- --dot <path>

## Building example programs with Nix (quick refs)
- C BLAS (CPU): nix-build -E 'with import <nixpkgs> {}; callPackage ./test/example-programs/blas-c/default.nix { isCpu = true; }'
- C BLAS (GPU via ROCm HIP): nix-build -E 'with import <nixpkgs> {}; callPackage ./test/example-programs/blas-c/default.nix { isCpu = false; rocblas = rocmPackages.rocblas; clr = rocmPackages.clr; }'
- Fortran BLAS (CPU): nix-build -E 'with import <nixpkgs> {}; callPackage ./test/example-programs/blas-fortran/default.nix { blas = blas; }'
- Python BLAS (CPU): nix-build -E 'with import <nixpkgs> {}; callPackage ./test/example-programs/blas-python/default.nix { }'
- Python BLAS (GPU via PyTorch): nix-build -E 'with import <nixpkgs> {}; callPackage ./test/example-programs/blas-python/default.nix { enableTorch = true; }'

For builds using the tuned package set, replace import <nixpkgs> {} with import ./zen-optimized-pkgs.nix {} and keep the same callPackage usage.

## Coding and style conventions
- JSON I/O: Keep field names, structure, and numeric formatting stable across languages. Ensure floats < 1 have a leading zero and fields do not overflow (avoid ***** by increasing width when using fixed-format Fortran writes).
- Determinism: Use deterministic initializers for matrices (LCG as implemented) and fixed seeds, so checksums remain stable.
- Minimal diffs: Avoid widespread reformatting; change only what is necessary to satisfy issues and tests.
- Nix expressions: Prefer small, explicit derivations mirroring existing patterns. Avoid unnecessary dependencies; use pkg-config when appropriate.
- Tool usage: Use project-specific tools (search_project, search_replace, etc.) and avoid mixing them with shell commands per environment rules.

## Build-and-test expectations before submit
- If you changed or added code that affects builds/tests, run the relevant nix-unit tests locally as described above.
- If you added a new example program, provide a default.nix and (if it produces JSON output) a small test.nix that runs it and stores result.json under $out/lib.
- Ensure README.adoc files for new example programs explain how to build and run them (CPU/GPU variants where applicable).

## Contacts and licensing
- License: See LICENSE (MIT).
- Documentation: See README.adoc and docu/*.adoc for additional background.
