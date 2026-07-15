#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Boreas 2D Benchmark Runner — SIFT method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=4
TEST_MODE=""

# SIFT defaults (from paramBenchMethods/boreasBenchmarkSIFTSweep.py)
SIFT_N=256
SIFT_RADIUS=140.0
SIFT_MATCHING_STEP=3
SIFT_NFEATURES=0
SIFT_N_OCTAVE_LAYERS=3
SIFT_CONTRAST_THRESHOLD=0.01
SIFT_EDGE_THRESHOLD=10
SIFT_SIGMA=1.2
SIFT_RATIO_THRESHOLD=0.6
SIFT_RANSAC_THRESHOLD=1.0
SIFT_RANSAC_CONFIDENCE=0.99

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) SIFT_N="$2"; shift 2 ;;
    --radius) SIFT_RADIUS="$2"; shift 2 ;;
    --matching_step) SIFT_MATCHING_STEP="$2"; shift 2 ;;
    --start_frame) EXTRA_ARGS+=("--start_frame" "$2"); shift 2 ;;
    --max_frames) EXTRA_ARGS+=("--max_frames" "$2"); shift 2 ;;
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

DATA_DIR="${DATA_DIR:-/home/tim-external/dataFolder/radar_boreas}"

RESULTS_DIR="benchmark_results/boreas2d"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${RESULTS_DIR}/run_boreas2d_${TIMESTAMP}_sift.log"
exec > >(tee -a "$LOG_FILE" 2>&1)

echo "=============================================="
echo "  Boreas 2D Benchmark — SIFT"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $SIFT_N"
echo "Radius:      $SIFT_RADIUS"
echo "Match step:  $SIFT_MATCHING_STEP"
echo "SIFT params: nfeatures=$SIFT_NFEATURES n_octave_layers=$SIFT_N_OCTAVE_LAYERS"
echo "             contrast_threshold=$SIFT_CONTRAST_THRESHOLD edge_threshold=$SIFT_EDGE_THRESHOLD"
echo "             sigma=$SIFT_SIGMA ratio_threshold=$SIFT_RATIO_THRESHOLD"
echo "             ransac_threshold=$SIFT_RANSAC_THRESHOLD confidence=$SIFT_RANSAC_CONFIDENCE"
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

METHOD_CONFIG="sift.sift_nfeatures=$SIFT_NFEATURES sift.sift_n_octave_layers=$SIFT_N_OCTAVE_LAYERS sift.sift_contrast_threshold=$SIFT_CONTRAST_THRESHOLD sift.sift_edge_threshold=$SIFT_EDGE_THRESHOLD sift.sift_sigma=$SIFT_SIGMA sift.sift_ratio_threshold=$SIFT_RATIO_THRESHOLD sift.sift_ransac_threshold=$SIFT_RANSAC_THRESHOLD sift.sift_ransac_confidence=$SIFT_RANSAC_CONFIDENCE"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/boreas2d/docker-entrypoint-benchmark-boreas2d.sh \
    --method sift \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$SIFT_N" \
    --radius "$SIFT_RADIUS" \
    --matching_step "$SIFT_MATCHING_STEP" \
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
