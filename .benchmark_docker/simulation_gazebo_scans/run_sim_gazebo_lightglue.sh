#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Lidar Simulation 2D Benchmark Runner — lightglue method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=1
TEST_MODE=""

# lightglue defaults
lightglue_N=256
lightglue_RADIUS=15.0
LIGHTGLUE_EXTRACTOR=superpoint
LIGHTGLUE_RATIO_THRESHOLD=0.7
LIGHTGLUE_RANSAC_THRESHOLD=1.0
LIGHTGLUE_RANSAC_CONFIDENCE=0.99

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) lightglue_N="$2"; shift 2 ;;
    --radius) lightglue_RADIUS="$2"; shift 2 ;;
    --lightglue-extractor) LIGHTGLUE_EXTRACTOR="$2"; shift 2 ;;
    --lightglue-ratio-threshold) LIGHTGLUE_RATIO_THRESHOLD="$2"; shift 2 ;;
    --lightglue-ransac-threshold) LIGHTGLUE_RANSAC_THRESHOLD="$2"; shift 2 ;;
    --lightglue-ransac-confidence) LIGHTGLUE_RANSAC_CONFIDENCE="$2"; shift 2 ;;
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
LOG_FILE="${RESULTS_DIR}/run_sim_gazebo_${TIMESTAMP}_lightglue.log"

echo "=============================================="
echo "  Lidar Simulation 2D Benchmark — lightglue"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           ${lightglue_N}"
echo "Radius:      ${lightglue_RADIUS}"
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

METHOD_CONFIG="lightglue.extractor=superpoint lightglue.ratio_threshold=0.7 lightglue.ransac_threshold=1.0 lightglue.ransac_confidence=0.99"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/simulation_gazebo_scans/\
docker-entrypoint-benchmark-simulation_gazebo_scans.sh \
    --method lightglue \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "${lightglue_N}" \
    --radius "${lightglue_RADIUS}" \
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
