#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Lidar Simulation 2D Benchmark Runner — FS2D method
#
# Usage:
#   bash .benchmark_docker/simulation_gazebo_scans/run_sim_gazebo_fs2d.sh [workers] [options]
#
# Examples:
#   # All datasets, 4 workers
#   bash .benchmark_docker/simulation_gazebo_scans/run_sim_gazebo_fs2d.sh 4
#
#   # Specific datasets
#   bash .benchmark_docker/simulation_gazebo_scans/run_sim_gazebo_fs2d.sh 4 --sequences 1-3
#
#   # Quick test
#   bash .benchmark_docker/simulation_gazebo_scans/run_sim_gazebo_fs2d.sh 2 --test
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=1
TEST_MODE=""
NOISE_LEVEL="None"

# FS2D defaults
FS2D_N=256
FS2D_RADIUS=15.0
FS2D_POTENTIAL_FOR_NECESSARY_PEAK=0.01
FS2D_LEVEL_POTENTIAL_ROTATION=0.0
FS2D_USE_DIRECT=true
FS2D_USE_CLACHE=false
FS2D_USE_HAMMING=true
FS2D_MULTIPLE_RADII=true
FS2D_USE_GAUSS=false
FS2D_NORMALIZATION=0
FS2D_R_MIN=20.0
FS2D_R_MAX=120.0
FS2D_USE_WEIGHTED_PEAK_SCORE=true
FS2D_USE_PHASE_CORRELATION=false

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --noise-level) NOISE_LEVEL="$2"; shift 2 ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) FS2D_N="$2"; shift 2 ;;
    --radius) FS2D_RADIUS="$2"; shift 2 ;;
    --potential_for_necessary_peak) FS2D_POTENTIAL_FOR_NECESSARY_PEAK="$2"; shift 2 ;;
    --level_potential_rotation) FS2D_LEVEL_POTENTIAL_ROTATION="$2"; shift 2 ;;
    --use-direct) FS2D_USE_DIRECT="$2"; shift 2 ;;
    --use-clahe) FS2D_USE_CLACHE="$2"; shift 2 ;;
    --use-hamming) FS2D_USE_HAMMING="$2"; shift 2 ;;
    --multiple-radii) FS2D_MULTIPLE_RADII="$2"; shift 2 ;;
    --use-gauss) FS2D_USE_GAUSS="$2"; shift 2 ;;
    --normalization) FS2D_NORMALIZATION="$2"; shift 2 ;;
    --r-min) FS2D_R_MIN="$2"; shift 2 ;;
    --r-max) FS2D_R_MAX="$2"; shift 2 ;;
    --use-weighted-peak-score) FS2D_USE_WEIGHTED_PEAK_SCORE="$2"; shift 2 ;;
    --use-phase-correlation) FS2D_USE_PHASE_CORRELATION="$2"; shift 2 ;;
    --save-blended) EXTRA_ARGS+=("--save-blended"); shift ;;
    --output-dir) EXTRA_ARGS+=("--output-dir" "$2"); shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    *) NUM_WORKERS="$1"; shift ;;
  esac
done

# === Data dir ===
DATA_DIR="${DATA_DIR:-/home/tim-external/dataFolder/2D-Scan-Gazebo-Dataset}"

# === Logging ===
RESULTS_DIR="benchmark_results/simulation_gazebo_scans"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${RESULTS_DIR}/run_sim_gazebo_${TIMESTAMP}_fs2d.log"

echo "=============================================="
echo "  Lidar Simulation 2D Benchmark — FS2D"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "Noise level:  $NOISE_LEVEL"
echo "N:           $FS2D_N"
echo "Radius:      $FS2D_RADIUS"
echo "FS2D params: use_clahe=$FS2D_USE_CLACHE use_hamming=$FS2D_USE_HAMMING"
echo "             use_direct=$FS2D_USE_DIRECT use_gauss=$FS2D_USE_GAUSS"
echo "             multiple_radii=$FS2D_MULTIPLE_RADII"
echo "             potential_peak=$FS2D_POTENTIAL_FOR_NECESSARY_PEAK"
echo "             level_rot=$FS2D_LEVEL_POTENTIAL_ROTATION"
echo "             normalization=$FS2D_NORMALIZATION"
echo "             r_min=$FS2D_R_MIN r_max=$FS2D_R_MAX"
echo "             weighted_peak=$FS2D_USE_WEIGHTED_PEAK_SCORE"
echo "             phase_corr=$FS2D_USE_PHASE_CORRELATION"
echo ""

# === Step 1: Build image (if needed) ===
if ! docker image inspect fsbench:latest >/dev/null 2>&1; then
  echo "=== [1/3] Building docker image ==="
  docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
  echo ""
else
  echo "=== Docker image fsbench:latest already exists ==="
fi

# === Step 2: Build workspace (if needed) ===
# First-time setup = full build. On later runs, rebuild fsregistration only
# when its sources are newer than the installed pybind module, so the module
# stays current without wiping install/ or re-downloading weights every run.
REBUILD_MSG=""
if [ -d "install/soft20" ]; then
  SOFILE=$(find install/fsregistration/lib/fsregistration -maxdepth 1 \
           -name 'pybind_registration_2d*.so' -print -quit 2>/dev/null || true)
  if [ -z "$SOFILE" ]; then
    REBUILD_MSG="pybind module not built"
  else
    STALE_SRC=$(find src/fsregistration/src src/fsregistration/include src/fsregistration/find-peaks \
                \( -name '*.cpp' -o -name '*.h' \) -newer "$SOFILE" -print -quit 2>/dev/null || true)
    if [ -n "$STALE_SRC" ]; then
      REBUILD_MSG="newer source: $STALE_SRC"
    fi
  fi
fi

if [ ! -d "install/soft20" ]; then
  echo "=== [2/3] Building workspace ==="
  docker run --rm \
    -v "$(pwd):/home/benchmark/ros_ws" \
    fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
  echo ""
elif [ -n "$REBUILD_MSG" ]; then
  echo "=== [2/3] Rebuilding fsregistration ($REBUILD_MSG) ==="
  docker run --rm \
    -v "$(pwd):/home/benchmark/ros_ws" \
    fsbench:latest bash -c \
      '. /opt/ros/jazzy/setup.bash && cd /home/benchmark/ros_ws && colcon build --packages-select fsregistration'
  echo ""
else
  echo "=== Workspace already built (install/soft20 exists) ==="
fi

# === Step 3: Run benchmark ===
echo "=== [3/3] Running Lidar Simulation 2D benchmark ==="

METHOD_CONFIG="fs2d.potential_for_necessary_peak=$FS2D_POTENTIAL_FOR_NECESSARY_PEAK fs2d.level_potential_rotation=$FS2D_LEVEL_POTENTIAL_ROTATION fs2d.use_direct=$FS2D_USE_DIRECT fs2d.use_clahe=$FS2D_USE_CLACHE fs2d.use_hamming=$FS2D_USE_HAMMING fs2d.multiple_radii=$FS2D_MULTIPLE_RADII fs2d.use_gauss=$FS2D_USE_GAUSS fs2d.normalization=$FS2D_NORMALIZATION fs2d.use_weighted_peak_score=$FS2D_USE_WEIGHTED_PEAK_SCORE fs2d.use_phase_correlation=$FS2D_USE_PHASE_CORRELATION fs2d.r_min=$FS2D_R_MIN fs2d.r_max=$FS2D_R_MAX"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/simulation_gazebo_scans/\
docker-entrypoint-benchmark-simulation_gazebo_scans.sh \
    --method fs2d \
    --num-workers "$NUM_WORKERS" \
    --noise-level "$NOISE_LEVEL" \
    --output-dir /volume/results \
    --N "$FS2D_N" \
    --radius "$FS2D_RADIUS" \
    ${TEST_MODE:+--test} \
    --method-config "$METHOD_CONFIG" \
    "${EXTRA_ARGS[@]}" \
    /data

EXIT_CODE=$?

# === Summary ===
echo ""
echo "=============================================="
echo "  Benchmark complete (exit code: $EXIT_CODE)"
echo "=============================================="
echo "Results: $(pwd)/${RESULTS_DIR}/"
echo ""

exit $EXIT_CODE
