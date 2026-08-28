#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Lidar Simulation 2D Benchmark Runner — kaze method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=1
TEST_MODE=""
NOISE_LEVEL="None"

# kaze defaults
kaze_N=256
kaze_RADIUS=15.0
KAZE_THRESHOLD=0.001
KAZE_NOCTAVES=4
KAZE_NOCTAVELAYERS=4
KAZE_EXTENDED=0
KAZE_UPRIGHT=0
KAZE_DIFFUSIVITY=2
KAZE_RATIO_THRESHOLD=0.7
KAZE_RANSAC_THRESHOLD=1.0
KAZE_RANSAC_CONFIDENCE=0.99

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --noise-level) NOISE_LEVEL="$2"; shift 2 ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) kaze_N="$2"; shift 2 ;;
    --radius) kaze_RADIUS="$2"; shift 2 ;;
    --kaze-threshold) KAZE_THRESHOLD="$2"; shift 2 ;;
    --kaze-nOctaves) KAZE_NOCTAVES="$2"; shift 2 ;;
    --kaze-nOctaveLayers) KAZE_NOCTAVELAYERS="$2"; shift 2 ;;
    --kaze-extended) KAZE_EXTENDED="$2"; shift 2 ;;
    --kaze-upright) KAZE_UPRIGHT="$2"; shift 2 ;;
    --kaze-diffusivity) KAZE_DIFFUSIVITY="$2"; shift 2 ;;
    --kaze-ratio-threshold) KAZE_RATIO_THRESHOLD="$2"; shift 2 ;;
    --kaze-ransac-threshold) KAZE_RANSAC_THRESHOLD="$2"; shift 2 ;;
    --kaze-ransac-confidence) KAZE_RANSAC_CONFIDENCE="$2"; shift 2 ;;
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
LOG_FILE="${RESULTS_DIR}/run_sim_gazebo_${TIMESTAMP}_kaze.log"

echo "=============================================="
echo "  Lidar Simulation 2D Benchmark — kaze"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "Noise level:  $NOISE_LEVEL"
echo "N:           ${kaze_N}"
echo "Radius:      ${kaze_RADIUS}"
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

METHOD_CONFIG="kaze.threshold=0.001 kaze.nOctaves=4 kaze.nOctaveLayers=4 kaze.extended=0 kaze.upright=0 kaze.diffusivity=2 kaze.ratio_threshold=0.7 kaze.ransac_threshold=1.0 kaze.ransac_confidence=0.99"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/simulation_gazebo_scans/\
docker-entrypoint-benchmark-simulation_gazebo_scans.sh \
    --method kaze \
    --num-workers "$NUM_WORKERS" \
    --noise-level "$NOISE_LEVEL" \
    --output-dir /volume/results \
    --N "${kaze_N}" \
    --radius "${kaze_RADIUS}" \
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
