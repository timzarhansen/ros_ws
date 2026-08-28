#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Lidar Simulation 2D Benchmark Runner — sift method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=1
TEST_MODE=""
NOISE_LEVEL="None"

# sift defaults
sift_N=256
sift_RADIUS=15.0
SIFT_NFEATURES=0
SIFT_N_OCTAVE_LAYERS=3
SIFT_CONTRAST_THRESHOLD=0.04
SIFT_EDGE_THRESHOLD=10
SIFT_SIGMA=1.6
SIFT_RATIO_THRESHOLD=0.6
SIFT_RANSAC_THRESHOLD=1.0
SIFT_RANSAC_CONFIDENCE=0.99

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --noise-level) NOISE_LEVEL="$2"; shift 2 ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) sift_N="$2"; shift 2 ;;
    --radius) sift_RADIUS="$2"; shift 2 ;;
    --sift-nfeatures) SIFT_NFEATURES="$2"; shift 2 ;;
    --sift-n-octave-layers) SIFT_N_OCTAVE_LAYERS="$2"; shift 2 ;;
    --sift-contrast-threshold) SIFT_CONTRAST_THRESHOLD="$2"; shift 2 ;;
    --sift-edge-threshold) SIFT_EDGE_THRESHOLD="$2"; shift 2 ;;
    --sift-sigma) SIFT_SIGMA="$2"; shift 2 ;;
    --sift-ratio-threshold) SIFT_RATIO_THRESHOLD="$2"; shift 2 ;;
    --sift-ransac-threshold) SIFT_RANSAC_THRESHOLD="$2"; shift 2 ;;
    --sift-ransac-confidence) SIFT_RANSAC_CONFIDENCE="$2"; shift 2 ;;
    --save-blended) EXTRA_ARGS+=("--save-blended"); shift ;;
    --output-dir) EXTRA_ARGS+=("--output-dir" "$2"); shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    *) NUM_WORKERS="$1"; shift ;;
  esac
done

DATA_DIR="${DATA_DIR:-/home/tim-external/dataFolder/2D-Scan-Gazebo-Dataset}"

RESULTS_DIR="benchmark_results/simulation_gazebo_scans"
mkdir -p "$RESULTS_DIR"
chmod 777 "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${RESULTS_DIR}/run_sim_gazebo_${TIMESTAMP}_sift.log"

echo "=============================================="
echo "  Lidar Simulation 2D Benchmark — sift"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "Noise level:  $NOISE_LEVEL"
echo "N:           ${sift_N}"
echo "Radius:      ${sift_RADIUS}"
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

METHOD_CONFIG="sift.nfeatures=0 sift.n_octave_layers=3 sift.contrast_threshold=0.01 sift.edge_threshold=10 sift.sigma=1.2 sift.ratio_threshold=0.6 sift.ransac_threshold=1.0 sift.ransac_confidence=0.99"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/simulation_gazebo_scans/\
docker-entrypoint-benchmark-simulation_gazebo_scans.sh \
    --method sift \
    --num-workers "$NUM_WORKERS" \
    --noise-level "$NOISE_LEVEL" \
    --output-dir /volume/results \
    --N "${sift_N}" \
    --radius "${sift_RADIUS}" \
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
