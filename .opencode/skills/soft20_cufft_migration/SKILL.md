---
name: soft20Migaration
description: This should help you headstart the migration. After this information intake, the user gives you the current problem.
---

# SOFT20 cuFFT Migration Skill


## Overall Goal

Migrate the **soft20** ROS package from FFTW (CPU-based) to cuFFT (GPU-based) implementation for SO(3) Fourier Transforms, targeting **4-6x speedup** on NVIDIA RTX 3090 (CUDA 13.1, compute capability 80).

The soft20 package provides spherical harmonic transforms for 3D image registration. The user wants to replace FFTW with cuFFT to leverage GPU acceleration.

## Repository Structure

```
/home/tim-external/volumeROS/src/soft20/
├── CMakeLists.txt              # Root CMake with USE_CUFFT option
├── docker_test/
│   ├── CMakeLists.txt          # Dual-backend build (FFTW + cuFFT)
│   ├── Dockerfile              # CUDA 13.1 container
│   ├── docker-compose.yml      # GPU-enabled compose
│   └── README.md               # Test documentation
├── include/
│   ├── soft20/                 # Modern namespaced headers (extern C guards)
│   └── *.h                     # Legacy flat headers
├── src/
│   ├── common/                 # Backend-agnostic shared code (6 files)
│   ├── lib1/                   # FFTW backend + cuFFT backend (15 .c + 3 .cu)
│   └── lib0/                   # Legacy symmetric backend (no FFTW)
├── examples/                   # cuFFT tests (2 .cu files)
├── examples1/                  # FFTW tests (10 .c files)
└── examples0/                  # Symmetric backend tests
```

## Build Commands

### Docker (Primary - requires GPU)
```bash
cd /home/tim-external/volumeROS/src/soft20/docker_test
docker compose build --no-cache
docker compose up
```

### Local CMake
```bash
# FFTW backend (default)
cmake -B build -DCMAKE_BUILD_TYPE=Release

# cuFFT backend
cmake -B build -DUSE_CUFFT=ON -DCMAKE_CUDA_ARCHITECTURES="80"
```

## Current State (as of 2026-05-15)

### Recent Fixes Applied
1. **FFTW API mismatch** (`rotate_so3_utils.c`): Removed deprecated `sign` parameter from `fftw_plan_guru_split_dft` (FFTW 3.3.8 bidirectional API) + removed 4 duplicate plan calls
2. **Duplicate code block** (`soft_cufft.cu`): Removed 190-line duplicated Wigner transform code that caused cascading parse errors
3. **Type casts** (`soft_cufft.cu`): Added `(cufftDoubleComplex*)` casts to all 4 `cufftExecZ2Z` calls for CUDA 13 compatibility
4. **Linker symbols** (`soft_cufft.cu`): Added `extern "C"` block to resolve C++ name mangling mismatch
5. **cuFFT stride fix** (`soft_cufft.cu`): Changed plan from strided `istride=n*n, odist=n*n` to contiguous `istride=1, idist=n, ostride=1, odist=n` — fixes OOB writes and sparse reads. AWAITING GPU TEST.
5. **cuFFT stride fix** (`soft_cufft.cu`): Changed plan from strided `istride=n*n, odist=n*n` to contiguous `istride=1, idist=n, ostride=1, odist=n` — fixes OOB writes and sparse reads. AWAITING GPU TEST.

### Migration Progress: ~30-40%

| Component | FFTW (CPU) | cuFFT (GPU) | Status |
|-----------|------------|-------------|--------|
| Main SO(3) forward/inverse FFT | `soft_fftw.c` | `soft_cufft.cu` | 🔧 Fixed (contiguous plan, awaiting GPU test) |
| Spherical harmonic FFT | `s2_semi_memo.c` | `s2_semi_memo_cufft.cu` | ✅ Migrated |
| High-level wrappers | `wrap_soft_fftw.c` | `wrap_soft_cufft.cu` | ✅ Migrated |
| Wigner transforms | `wignerTransforms_fftw.c` | NOT MIGRATED | ❌ CPU only |
| Legendre transforms | `s2_legendreTransforms.c` | NOT MIGRATED | ❌ CPU only |
| SO(3) correlation | `so3_correlate_fftw.c` | NOT MIGRATED | ❌ CPU only |
| S2 rotation | `rotate_so3_fftw.c` | NOT MIGRATED | ❌ CPU only |
| Variant transforms (_nt, _pc) | `soft_fftw_nt.c`, `soft_fftw_pc.c` | NOT MIGRATED | ❌ CPU only |
| Complex vector utilities | `utils_vec_cx.c` | NOT MIGRATED | ❌ CPU only |

### Architecture

The cuFFT backend is **hybrid**:
- FFT operations run on GPU via cuFFT (`cufftExecZ2Z`)
- Wigner-D matrix transforms still run on CPU
- Data is copied H2D/D2H between FFT and Wigner stages
- This is intentional: FFT is the bottleneck, Wigner transforms are less compute-intensive

### Known Issues

1. **Root CMakeLists.txt linkage**: `USE_CUFFT=ON` build is broken - missing source files (`wignerTransforms_fftw.c`, `s2_legendreTransforms.c`, `utils_vec_cx.c`) and doesn't link FFTW for DCT operations
2. **docker_test builds both backends**: The docker_test CMakeLists.txt builds `soft20_fftw` AND `soft20_cufft` separately, avoiding the root CMake linkage issues
3. **cuFFT still depends on FFTW types**: The `.cu` files include `<fftw3.h>` for `fftw_complex` typedef (layout-compatible with `cuDoubleComplex`)
4. **~~cuFFT plan `odist` parameter is `n*n` (should be `n`)~~ FIXED 2026-05-15**: Changed to contiguous plan: `istride=1, idist=n, ostride=1, odist=n`. Both forward and inverse plans. Awaiting GPU test.
5. **FFTW access pattern is `n*(k+j)`, not `k*n + j*n^2`**: Tracing through FFTW's `fftw_plan_many_dft` internal conversion to the guru split interface with `inembed={n, n^2}, istride=1, idist=n` gives `dim[1].is = istride * inembed[0] = n`. The actual physical index formula for batch k, element j is `k*n + j*n = n*(k+j)` — an overlapping strided pattern. The earlier analysis in `fftw_transfer_to_cufft.md` that claimed `k*n + j*n^2` is incorrect. See that file for the detailed trace.

## Key Files

### CUDA Implementation Files
- `src/lib1/soft_cufft.cu` - Main SO(3) transform on GPU (921 lines)
- `src/lib1/s2_semi_memo_cufft.cu` - Spherical harmonic FFT on GPU (349 lines)
- `src/lib1/wrap_soft_cufft.cu` - High-level wrappers (103 lines)

### Critical FFTW-Only Files (migration targets)
- `src/lib1/wignerTransforms_fftw.c` - Wigner-D FFT transforms
- `src/lib1/s2_legendreTransforms.c` - Legendre polynomial transforms
- `src/lib1/rotate_so3_utils.c` - Core rotation utilities (contains `rotateFct_mem`)
- `src/lib1/rotate_so3_fftw.c` - S2 rotation wrappers

### Headers
- `include/soft20/soft_fftw.h` - Dual-mode header (`USE_CUFFT` conditional)
- `include/soft20/wignerTransforms_fftw.h` - Wigner transform declarations
- `include/soft20/FST_semi_memo.h` - Spherical harmonic transform declarations

### Test Files
- `examples/test_cufft_compare.cu` - FFTW vs cuFFT comparison test
- `examples/test_cufft_backend.cu` - Standalone cuFFT backend test

## Migration Strategy

### Phase 1: Build Stability ✅ DONE
- Fix FFTW API compatibility issues
- Fix CUDA 13 type mismatches
- Fix linker symbol issues
- Ensure docker_test builds successfully

### Phase 2: Core GPU Acceleration ⚠️ PARTIALLY DONE (awaiting GPU test)
- Migrate main SO(3) FFT stages to cuFFT
- Migrate spherical harmonic FFT to cuFFT
- Create hybrid architecture (GPU FFT + CPU Wigner)
- **FIXED (untested)**: cuFFT plan stride bug — changed to contiguous `istride=1, idist=n, ostride=1, odist=n`

### Phase 2.5: Fix cuFFT Stride Bug ✅ APPLIED — AWAITING GPU TEST
1. ~~**Option G (minimal fix)**~~ — Not needed. The contiguous plan makes cuFFT output match `transpose_cx` directly without GPU transpose kernels.
2. **Applied**: Changed both Forward and Inverse cuFFT plans in `soft_cufft.cu` from `istride=n*n, idist=n, ostride=1, odist=n*n` to `istride=1, idist=n, ostride=1, odist=n`. The contiguous output layout `workspace_cx[b*n + j]` matches what `transpose_cx(arrayIn, arrayOut, n*n, n)` expects when treating the buffer as `(n²×n)` row-major.
3. **No GPU transpose kernels needed**: The algorithm's natural data layout is already contiguous 3D `[i + n*j + n²*k]`. The cuFFT plan now processes this directly without any stride mismatch.
4. **Next**: Build and run `docker compose up --build` in `docker_test/` to validate bw=8 and bw=128.

### Phase 3: Remaining Migration (TODO)
1. **Fix root CMakeLists.txt**: Make `USE_CUFFT=ON` build work by including necessary shared sources
2. **GPU-accelerate Wigner transforms**: Move `wignerTransforms_fftw.c` to GPU (CUDA kernels)
3. **GPU-accelerate Legendre transforms**: Move `s2_legendreTransforms.c` to GPU
4. **Migrate remaining functions**: S2 rotation, correlation, variant transforms
5. **Optimize data transfers**: Minimize H2D/D2H copies between stages

### Phase 4: Validation
- Ensure numerical accuracy matches FFTW backend (L2 error < 1e-5, max error < 1e-4)
- Benchmark performance improvements
- Test on multiple GPU architectures

## Important Notes

- **CUDA 13.1** requires compute capability 80+ (RTX 30xx, A100, H100)
- **FFTW 3.3.8** (Ubuntu 22.04) has bidirectional plans - no `sign` parameter in `plan_guru_split_dft`
- **cufftDoubleComplex** is `double2` struct in CUDA 13, NOT `double[2]` like `fftw_complex` - explicit casts required
- **extern "C"** required for functions declared in headers with C linkage when defined in .cu files
- The docker_test container uses `nvidia/cuda:13.1.0-devel-ubuntu22.04` base image
- **FFTW strided access**: The FFTW plan's `istride=1, idist=n` with `inembed={n,n²}` translates internally to guru dims with `dim[1].is = istride * inembed[0] = n` (NOT `n²`). The actual memory access pattern is `n*(k+j)` — an overlapping stride where consecutive batches' read windows overlap. `FFTW_MEASURE` handles this internally. cuFFT's `PlanMany` does NOT support overlapping batches.
- **odist bug (FIXED 2026-05-15)**: cuFFT plan changed to contiguous: `istride=1, idist=n, ostride=1, odist=n`. Output layout is `batch_k[n*k + j]` — matches `transpose_cx` expectation of `(n²×n)` row-major matrix.
- See `src/soft20/fftw_transfer_to_cufft.md` for the full 9-attempt history, debug output, and detailed root cause analysis.

## Commit History (Recent)

```
26133a9 fix: add extern C to soft_cufft.cu to resolve linker symbol mismatch
5f8b747 fix: remove duplicate code block and fix cufftExecZ2Z type casts for CUDA 13
1600195 fix: update fftw_plan_guru_split_dft for FFTW 3.3.8 bidirectional API
```
