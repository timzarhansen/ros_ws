#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Lidar Simulation 2D Benchmark Runner — fourier_mellin method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=1
TEST_MODE=""

# fourier_mellin defaults
fourier_mellin_N=256
fourier_mellin_RADIUS=15.0
FOURIER_MELLIN_ROTATION_TOLERANCE=5.0
FOURIER_MELLIN_TRANSLATION_TOLERANCE=5.0
FOURIER_MELLIN_HIGHPASS_FILTER=1
FOURIER_MELLIN_USE_PHASE_CORRELATION=0

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) fourier_mellin_N="$2"; shift 2 ;;
    --radius) fourier_mellin_RADIUS="$2"; shift 2 ;;
    --fourier-rotation-tolerance) FOURIER_MELLIN_ROTATION_TOLERANCE="$2"; shift 2 ;;
    --fourier-translation-tolerance) FOURIER_MELLIN_TRANSLATION_TOLERANCE="$2"; shift 2 ;;
    --fourier-highpass-filter) FOURIER_MELLIN_HIGHPASS_FILTER="$2"; shift 2 ;;
    --fourier-use-phase-correlation) FOURIER_MELLIN_USE_PHASE_CORRELATION="$2"; shift 2 ;;
    --save-blended) EXTRA_ARGS+=("--save-blended"); shift ;;
    --output-dir) EXTRA_ARGS+=("--output-dir" "$2"); shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    *) NUM_WORKERS="$1"; shift ;;
  esac
done

DATA_DIR="${DATA_DIR:-/home/tim-external/dataFolder/simulation_gazebo_scans}"

RESULTS_DIR="benchmark_results/simulation_gazebo_scans"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${RESULTS_DIR}/run_sim_gazebo_${TIMESTAMP}_fourier_mellin.log"

echo "=============================================="
echo "  Lidar Simulation 2D Benchmark — fourier_mellin"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           ${fourier_mellin_N}"
echo "Radius:      ${fourier_mellin_RADIUS}"
echo ""

if ! docker image inspect fsbench:latest >/dev/null 2>&1; then
  echo "=== [1/3] Building docker image ==="
  docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
else
  echo "=== Docker image fsbench:latest already exists ==="
fi

if [ ! -d "install/soft20" ]; then
  echo "=== [2/3] Building workspace ==="
  docker run --rm     -v "$(pwd):/home/benchmark/ros_ws"     fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
else
  echo "=== Workspace already built (install/soft20 exists) ==="
fi

echo "=== [3/3] Running Lidar Simulation 2D benchmark ==="

METHOD_CONFIG="fourier_mellin.rotation_tolerance=5.0 fourier_mellin.translation_tolerance=5.0 fourier_mellin.highpass_filter=1 fourier_mellin.use_phase_correlation=0"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/simulation_gazebo_scans/\
docker-entrypoint-benchmark-simulation_gazebo_scans.sh \
    --method fourier_mellin \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "${fourier_mellin_N}" \
    --radius "${fourier_mellin_RADIUS}" \
    ${TEST_MODE:+--test} \
    --method-config "$METHOD_CONFIG" \
    "${EXTRA_ARGS[@]}" \
    /data

EXIT_CODE=$?

echo ""
echo "=============================================="
echo "  Benchmark complete (exit code: $EXIT_CODE)"
echo "=============================================="
echo "Results: $(pwd)/${RESULTS_DIR}/"
echo ""

exit $EXIT_CODE
