#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Lidar Simulation 2D Benchmark Runner — akaze method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=1
TEST_MODE=""
NOISE_LEVEL="None"

# akaze defaults
akaze_N=256
akaze_RADIUS=15.0
AKAZE_THRESHOLD=0.001
AKAZE_NOCTAVES=4
AKAZE_NOCTAVELAYERS=4
AKAZE_RATIO_THRESHOLD=0.7
AKAZE_RANSAC_THRESHOLD=1.0
AKAZE_RANSAC_CONFIDENCE=0.99

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --noise-level) NOISE_LEVEL="$2"; shift 2 ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) akaze_N="$2"; shift 2 ;;
    --radius) akaze_RADIUS="$2"; shift 2 ;;
    --akaze-threshold) AKAZE_THRESHOLD="$2"; shift 2 ;;
    --akaze-nOctaves) AKAZE_NOCTAVES="$2"; shift 2 ;;
    --akaze-nOctaveLayers) AKAZE_NOCTAVELAYERS="$2"; shift 2 ;;
    --akaze-ratio-threshold) AKAZE_RATIO_THRESHOLD="$2"; shift 2 ;;
    --akaze-ransac-threshold) AKAZE_RANSAC_THRESHOLD="$2"; shift 2 ;;
    --akaze-ransac-confidence) AKAZE_RANSAC_CONFIDENCE="$2"; shift 2 ;;
    --save-blended) EXTRA_ARGS+=("--save-blended"); shift ;;
    --output-dir) EXTRA_ARGS+=("--output-dir" "$2"); shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    *) NUM_WORKERS="$1"; shift ;;
  esac
done

DATA_DIR="${DATA_DIR:-/home/tim-external/dataFolder/2D-Scan-Gazebo-Dataset}"

RESULTS_DIR="benchmark_results/simulation_gazebo_scans"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${RESULTS_DIR}/run_sim_gazebo_${TIMESTAMP}_akaze.log"

echo "=============================================="
echo "  Lidar Simulation 2D Benchmark — akaze"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "Noise level:  $NOISE_LEVEL"
echo "N:           ${akaze_N}"
echo "Radius:      ${akaze_RADIUS}"
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

METHOD_CONFIG="akaze.threshold=0.001 akaze.nOctaves=4 akaze.nOctaveLayers=4 akaze.ratio_threshold=0.7 akaze.ransac_threshold=1.0 akaze.ransac_confidence=0.99"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/simulation_gazebo_scans/\
docker-entrypoint-benchmark-simulation_gazebo_scans.sh \
    --method akaze \
    --num-workers "$NUM_WORKERS" \
    --noise-level "$NOISE_LEVEL" \
    --output-dir /volume/results \
    --N "${akaze_N}" \
    --radius "${akaze_RADIUS}" \
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
