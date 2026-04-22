# Autoresearch: Optimize 2D Registration NEW Method

## Objective
Optimize the NEW (1-Angle Direct) registration method in `fsregistration` package to reduce total registration time while maintaining result accuracy equal to the OLD (Full SO(3)) method.

The NEW method computes 2D image registration using spherical harmonic transforms with a simplified 1-angle correlation approach. Current implementation is ~4x faster than OLD method but can be further optimized through parallelization, pre-computation, and algorithmic improvements.

## Metrics
- **Primary**: `total_time_new` (ms, lower is better) - Total registration time for NEW method
- **Secondary**: 
  - `rotation_time_new` (ms) - Rotation detection time
  - `translation_time_new` (ms) - Translation detection time  
  - `speedup_vs_old` (ratio) - Speedup relative to OLD method
  - `speedup_vs_baseline` (ratio) - Speedup relative to initial NEW method baseline

## How to Run
```bash
cd /home/tim-external/volumeROS
./autoresearch.sh
```

Outputs `METRIC name=number` lines that can be parsed automatically.

## Files in Scope
- `/home/tim-external/volumeROS/src/fsregistration/src/softRegistrationClass.cpp` - Main registration implementation (PRIMARY TARGET)
- `/home/tim-external/volumeROS/src/fsregistration/src/softCorrelationClass.cpp` - Correlation computation
- `/home/tim-external/volumeROS/src/soft20/include/*.h` - Spherical harmonic transforms (FST_semi_memo, etc.)

## Off Limits
- OLD method implementation (`sofftRegistrationVoxel2DListOfPossibleRotations`, `registrationOfTwoVoxelsSO3`)
- Test file `test_full_registration_comparison.cpp` (frozen - no changes allowed)
- Test file `test_1angle_comparison.cpp`
- Any files outside `fsregistration` and `soft20` packages

## Constraints
1. **Tests MUST pass**: Both `test_full_registration_comparison` and `test_1angle_comparison` must pass after each experiment
2. **Accuracy requirement**: Results must match OLD method within tolerance:
   - Rotation difference < 0.01 rad (0.57°)
   - Translation difference < 1 pixel
3. **No new dependencies**: Only use existing libraries (OpenCV, FFTW, OpenMP, Eigen)
4. **API compatibility**: Method signatures must remain unchanged
5. **Exact numerical accuracy required**: Conservative approach - no approximations that affect precision

## Test Executable
`/home/tim-external/volumeROS/cache/humble/build/fsregistration/test_full_registration_comparison`

## Baseline Performance (Initial NEW Method)
- OLD method: ~2300 ms total
- NEW method: ~580 ms total (4x faster than OLD)
- Both methods produce identical results (rotation diff = 0°, translation diff = 0)

## Key Functions to Optimize (NEW method path)

### 1. `registrationOfTwoVoxelsDirect()` (lines 2070-2127)
- Full registration wrapper
- Sequential processing of detected angles
- For each angle: copy data → Gaussian blur → rotate → detect translations
- **Optimization opportunities**: Parallelize angle processing, pre-compute shared data

### 2. `sofftRegistrationVoxel2DListOfPossibleRotations1Angle()` (lines 621-874)
- Rotation detection via 1-angle correlation
- Steps:
  1. FFT of input images
  2. Resample to spherical grid (lines 664-706) - TRIGONOMETRIC HOTSPOT
  3. Compute spherical harmonic coefficients via FST_semi_memo()
  4. Compute Pm coefficients (lines 758-788)
  5. Compute 1D correlation C(α) (lines 792-804) - DIRECT DFT
  6. Peak detection with rotation trick (lines 822-871)
- **Optimization opportunities**: Pre-compute trig tables, replace DFT with FFT, vectorize

### 3. `sofftRegistrationVoxel2DTranslationAllPossibleSolutions()` (lines 1522-1751)
- Translation detection via 2D correlation
- Steps:
  1. FFT of rotated and reference images
  2. Complex correlation computation
  3. IFFT
  4. Peak detection
- **Optimization opportunities**: Pre-compute FFT of reference image, optimize peak detection

## Optimization Strategies (Priority Order)

### Phase 1: Parallelization (Quick Wins)
1. **Parallelize angle processing** with OpenMP `#pragma omp parallel for`
   - Expected: 2-4x speedup
   - Risk: Low (standard pattern, already used in SO3 method)
   
2. **Pre-compute FFT of voxelData2** before angle loop
   - Expected: 1.2-1.5x speedup
   - Risk: Low (mathematically equivalent)

3. **Pre-compute Gaussian blur of voxelData2** before angle loop
   - Expected: 1.1-1.3x speedup
   - Risk: Low (deterministic operation)

### Phase 2: Algorithmic Improvements
1. **Replace direct DFT with FFT** for 1D correlation computation (lines 792-804)
   - Current: O(nAlpha × bw) with sin/cos
   - Optimized: O(nAlpha log nAlpha) with FFTW
   - Expected: 2-3x speedup for this section
   - Risk: Medium (verify numerical equivalence)

2. **Pre-compute trigonometric lookup tables**
   - Target: Spherical grid resampling (lines 667-670) and 1D correlation (lines 799-800)
   - Expected: 1.1-1.3x speedup
   - Risk: Low (exact values, no approximation)

### Phase 3: Advanced Optimizations
1. **SIMD vectorization** of hot loops
   - Target: Spherical grid resampling, Pm computation, translation correlation
   - Expected: 2-4x for vectorized sections
   - Risk: Medium (careful testing required)

2. **Memory layout optimization** for cache efficiency
   - Expected: 1.1-1.5x speedup
   - Risk: Low-Medium

3. **Reduce peak detection overhead**
   - Early termination, coarse-to-fine approach
   - Expected: 1.1-1.2x speedup
   - Risk: Low

## What's Been Tried
- Initial baseline measurement: NEW method ~580 ms total
- Bug fix: Added rotation trick before peak detection (fixed 0° vs 12.66° bug)
- Refactoring: Split OLD (SO3) and NEW (Direct) methods into separate implementations
- Full registration methods added: `registrationOfTwoVoxelsSO3()` and `registrationOfTwoVoxelsDirect()`
- Test file frozen and stable

## Build Command
```bash
cd /home/tim-external/volumeROS
colcon build --packages-select fsregistration
```

## Test Command
```bash
cd /home/tim-external/volumeROS/cache/humble/build/fsregistration
LD_LIBRARY_PATH=/home/tim-external/volumeROS/cache/humble/install/soft20/lib:$LD_LIBRARY_PATH ./test_full_registration_comparison
```

## Expected Performance Targets
| Phase | Target NEW Time | Speedup vs Baseline |
|-------|----------------|---------------------|
| Baseline | ~580 ms | 1.0x |
| Phase 1 | ~150-290 ms | 2-4x |
| Phase 2 | ~100-200 ms | 3-6x |
| Phase 3 | ~60-130 ms | 4.5-10x |
| Final | ~50-100 ms | 6-12x |

## Notes
- OpenMP is already included (`#include <omp.h>`)
- FFTW is already used for FFT operations
- Typical number of detected angles: 1-3
- Image size: 256×256 pixels (N=256)
- Bandwidth: 128 (bw = N/2)
