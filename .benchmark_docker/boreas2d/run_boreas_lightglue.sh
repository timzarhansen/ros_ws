#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Boreas 2D Benchmark Runner — LightGlue method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=4
TEST_MODE=""

# LightGlue defaults (from paramBenchMethods/boreasBenchmarkLightGlueSweep.py)
LG_N=256
LG_RADIUS=140.0
LG_MATCHING_STEP=3
LG_FEATURES=superpoint
LG_MAX_NUM_KEYPOINTS=2048
LG_DEPTH_CONFIDENCE=0.95
LG_WIDTH_CONFIDENCE=-1
LG_FILTER_THRESHOLD=0.1
LG_RANSAC_THRESHOLD=3.0
LG_RANSAC_CONFIDENCE=0.99

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) LG_N="$2"; shift 2 ;;
    --radius) LG_RADIUS="$2"; shift 2 ;;
    --matching_step) LG_MATCHING_STEP="$2"; shift 2 ;;
    --start_frame) EXTRA_ARGS+=("--start_frame" "$2"); shift 2 ;;
    --max_frames) EXTRA_ARGS+=("--max_frames" "$2"); shift 2 ;;
    --lightglue-features) LG_FEATURES="$2"; shift 2 ;;
    --lightglue-max-num-keypoints) LG_MAX_NUM_KEYPOINTS="$2"; shift 2 ;;
    --lightglue-depth-confidence) LG_DEPTH_CONFIDENCE="$2"; shift 2 ;;
    --lightglue-width-confidence) LG_WIDTH_CONFIDENCE="$2"; shift 2 ;;
    --lightglue-filter-threshold) LG_FILTER_THRESHOLD="$2"; shift 2 ;;
    --lightglue-ransac-threshold) LG_RANSAC_THRESHOLD="$2"; shift 2 ;;
    --lightglue-ransac-confidence) LG_RANSAC_CONFIDENCE="$2"; shift 2 ;;
    --save-blended) EXTRA_ARGS+=("--save-blended"); shift ;;
    --output-dir) EXTRA_ARGS+=("--output-dir" "$2"); shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    *) NUM_WORKERS="$1"; shift ;;
  esac
done

DATA_DIR="${DATA_DIR:-/home/tim-external/dataFolder/radar_boreas}"

RESULTS_DIR="benchmark_results/boreas2d"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${RESULTS_DIR}/run_boreas2d_${TIMESTAMP}_lightglue.log"
exec > >(tee -a "$LOG_FILE" 2>&1)

echo "=============================================="
echo "  Boreas 2D Benchmark — LightGlue"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $LG_N"
echo "Radius:      $LG_RADIUS"
echo "Match step:  $LG_MATCHING_STEP"
echo "LightGlue params: features=$LG_FEATURES max_kp=$LG_MAX_NUM_KEYPOINTS"
echo "                  depth_conf=$LG_DEPTH_CONFIDENCE width_conf=$LG_WIDTH_CONFIDENCE"
echo "                  filter=$LG_FILTER_THRESHOLD"
echo "                  ransac_threshold=$LG_RANSAC_THRESHOLD confidence=$LG_RANSAC_CONFIDENCE"
echo ""

if ! docker image inspect fsbench:latest >/dev/null 2>&1; then
  echo "=== [1/3] Building docker image ==="
  docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
  echo ""
else
  echo "=== Docker image fsbench:latest already exists ==="
fi

if [ ! -d "install/soft20" ]; then
  echo "=== [2/3] Building workspace ==="
  docker run --rm \
    -v "$(pwd):/home/benchmark/ros_ws" \
    fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
  echo ""
else
  echo "=== Workspace already built (install/soft20 exists) ==="
fi

echo "=== [3/3] Running Boreas 2D benchmark ==="

METHOD_CONFIG="lightglue.lightglue_features=$LG_FEATURES lightglue.lightglue_max_num_keypoints=$LG_MAX_NUM_KEYPOINTS lightglue.lightglue_depth_confidence=$LG_DEPTH_CONFIDENCE lightglue.lightglue_width_confidence=$LG_WIDTH_CONFIDENCE lightglue.lightglue_filter_threshold=$LG_FILTER_THRESHOLD lightglue.lightglue_ransac_threshold=$LG_RANSAC_THRESHOLD lightglue.lightglue_ransac_confidence=$LG_RANSAC_CONFIDENCE"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/boreas2d/docker-entrypoint-benchmark-boreas2d.sh \
    --method lightglue \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$LG_N" \
    --radius "$LG_RADIUS" \
    --matching_step "$LG_MATCHING_STEP" \
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
ls -la "${RESULTS_DIR}/combined/"*.csv 2>/dev/null && echo "Combined summary available."
echo ""

exit $EXIT_CODE
