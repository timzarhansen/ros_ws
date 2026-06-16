---
name: fsregistration
description: Context for the fsregistration project – SOFT-based 2D/3D registration estimation for sonar data. Load at start of session.
---

# fsregistration Project Context

**Location**: `/home/tim-external/ros_ws/src/fsregistration/`
**Package**: ROS2 C++ package implementing SOFT (Spherical Harmonic Transform) for image/voxel registration.
**Author**: Tim Hansen (Constructor University)

## What It Does

Registers two sonar scans (2D images or 3D voxels) by estimating relative pose (rotation + translation) via spherical harmonic correlation on SO(3). Core idea: rotation-invariant features from Fourier magnitude projected onto S², then correlated via spherical harmonics.

## Key Classes

### 2D Registration – `softRegistrationClass`
- **Files**: `include/softRegistrationClass.h`, `src/softRegistrationClass.cpp`
- Operates on grayscale 2D sonar images (size N: 32–512).
- **Pipeline**:
  1. FFT each image → magnitude + phase
  2. Normalize, FFT-shift, apply CLAHE + Hamming window
  3. Project 2D Fourier magnitude onto S² sphere (radial sampling)
  4. SO(3) correlation via spherical harmonics (soft20 library)
  5. Extract 1D correlation curve → peak detection → candidate rotation angles
  6. Rotate scan 2 by estimated rotation → 2D phase correlation → candidate translations
- **Key methods**:
  - `registrationOfTwoVoxelsSOFFTFast()` – single best solution near initial guess
  - `registrationOfTwoVoxelsSOFFTAllSoluations()` – all solutions
  - `sofftRegistrationVoxel2DRotationOnlySO3()` / `RotationOnlyDirect()` – rotation-only
  - `sofftRegistrationVoxel2DTranslationAllPossibleSolutions()` – translation-only
- **Data types**: `rotationPeakfs2D`, `translationPeakfs2D`, `transformationPeakfs2D`

### 3D Registration – `softRegistrationClass3D`
- **Files**: `include/softRegistrationClass3D.h`, `src/softRegistrationClass3D.cpp`
- Operates on 3D voxel data (size N: 16–256).
- **Pipeline**: same SO(3) approach, but on 3D Fourier magnitude.
  - Rotation peaks detected in 4D quaternion space via KD-tree neighbor search
  - Translation via 3D phase correlation (FFT)
- **Key methods**:
  - `sofftRegistrationVoxel3DOneSolution()` – single best solution
  - `sofftRegistrationVoxel3DListOfPossibleTransformations()` – all solutions
- **Data types**: `rotationPeak4D` (quaternion), `translationPeak3D`, `transformationPeakfs3D`

### SO(3) Correlation Engine
- **Files**: `include/softCorrelationClass.h`, `src/softCorrelationClass.cpp` (+ 3D variants)
- Wraps soft20 library: `correlationOfTwoSignalsInSO3()`
- Manages FFTW plans, Wigner-d coefficients, semi-naive tables

## Peak Detection

- **Simple**: `PeakFinder` (1D/2D threshold-based)
- **Persistence-based**: `find-peaks/` – C++ port of Stefan Huber's persistent homology algorithm. Robust 3D peak detection, sorted by significance (persistence value).
- **Key parameters**:
  - `level_potential_rotation` (default 0.01) – rotation peak threshold
  - `level_potential_translation` (default 0.1) – translation peak threshold

## ROS2 Services

| Service | Node | Description |
|---------|------|-------------|
| `fs2d/registration/one_solution` | `ros2ServiceRegistrationFS2D` | Single 2D solution near initial guess |
| `fs2d/registration/all_solutions` | `ros2ServiceRegistrationFS2D` | All 2D solutions |
| `fs3D/registration/one_solution` | `ros2ServiceRegistrationFS3D` | Single 3D solution |
| `fs3D/registration/all_solutions` | `ros2ServiceRegistrationFS3D` | All 3D solutions |

**Service source**: `src/serviceRegistrationImage.cpp` (2D), `src/serviceRegistrationVoxel.cpp` (3D)

## Key Parameters

| Param | Default | Meaning |
|-------|---------|---------|
| `N` | varies | Grid size (32–512 for 2D, 16–256 for 3D) |
| `bwOut`, `bwIn` | N/2 | Harmonic bandwidth in/out |
| `degLim` | N/2-1 | Degree limit for spherical harmonics |
| `r_min` / `r_max` | N/8, N/2-N/8 | Radial frequency filter range |
| `useClahe` | true | CLAHE contrast enhancement |
| `useHamming` | true | Hamming window |
| `useSimpleRotationPeak` | false | Simple max vs persistence for rotation |
| `useSimpleTranslationPeak` | false | Simple max vs persistence for translation |
| `set_normalization` | 0 | Correlation normalization mode |

## ML Registration (experimental)
- `ml_registration/` – GeoTransformer, HybridPoint, RegTR, PointRegGPT models
- `pythonScripts/matchingProfiling3D/` – profiling scripts

## GPU Acceleration
- CPU (FFTW/soft20): production-ready
- GPU (cuFFT): build soft20 with `-DUSE_CUFFT=ON`
- See `README_GPU.md`, `FEATURE_PLAN.md` for targets and optimization plan

## Build
Standard ROS2 colcon build. Dependencies: ROS2, soft20, OpenCV, PCL, Eigen3, FFTW3, OpenMP, CGAL.
