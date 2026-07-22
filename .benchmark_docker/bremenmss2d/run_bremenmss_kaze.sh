#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Bremen-MSS 2D Benchmark Runner — KAZE method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=4
TEST_MODE=""

# KAZE defaults
KAZE_N=256
KAZE_RADIUS=22.5
KAZE_NFEATURES=0
KAZE_N_OCTAVE_LAYERS=3
KAZE_CONTRAST_THRESHOLD=0.01
KAZE_EDGE_THRESHOLD=10
KAZE_SIGMA=1.2
KAZE_RATIO_THRESHOLD=0.6
KAZE_RANSAC_THRESHOLD=1.0
KAZE_RANSAC_CONFIDENCE=0.99
KAZE_EXTENDED=0
KAZE_UPRIGHT=false

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) KAZE_N="$2"; shift 2 ;;
    --radius) KAZE_RADIUS="$2"; shift 2 ;;
    --kaze-nfeatures) KAZE_NFEATURES="$2"; shift 2 ;;
    --kaze-n-octave-layers) KAZE_N_OCTAVE_LAYERS="$2"; shift 2 ;;
    --kaze-contrast-threshold) KAZE_CONTRAST_THRESHOLD="$2"; shift 2 ;;
    --kaze-edge-threshold) KAZE_EDGE_THRESHOLD="$2"; shift 2 ;;
    --kaze-sigma) KAZE_SIGMA="$2"; shift 2 ;;
    --kaze-ratio-threshold) KAZE_RATIO_THRESHOLD="$2"; shift 2 ;;
    --kaze-ransac-threshold) KAZE_RANSAC_THRESHOLD="$2"; shift 2 ;;
    --kaze-ransac-confidence) KAZE_RANSAC_CONFIDENCE="$2"; shift 2 ;;
    --kaze-extended) KAZE_EXTENDED="$2"; shift 2 ;;
    --kaze-upright) KAZE_UPRIGHT="$2"; shift 2 ;;
    --save-blended) EXTRA_ARGS+=("--save-blended"); shift ;;
    --output-dir) EXTRA_ARGS+=("--output-dir" "$2"); shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    *) NUM_WORKERS="$1"; shift ;;
  esac
done

DATA_DIR="${DATA_DIR:-/home/tim-external/dataFolder/Bremen-MSS-Processed}"

RESULTS_DIR="benchmark_results/bremenmss2d"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${RESULTS_DIR}/run_bremenmss2d_${TIMESTAMP}_kaze.log"

echo "=============================================="
echo "  Bremen-MSS 2D Benchmark — KAZE"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $KAZE_N"
echo "Radius:      $KAZE_RADIUS"
echo "KAZE params: nfeatures=$KAZE_NFEATURES n_octave_layers=$KAZE_N_OCTAVE_LAYERS"
echo "             contrast_threshold=$KAZE_CONTRAST_THRESHOLD edge_threshold=$KAZE_EDGE_THRESHOLD"
echo "             sigma=$KAZE_SIGMA ratio_threshold=$KAZE_RATIO_THRESHOLD"
echo "             ransac_threshold=$KAZE_RANSAC_THRESHOLD confidence=$KAZE_RANSAC_CONFIDENCE"
echo "             extended=$KAZE_EXTENDED upright=$KAZE_UPRIGHT"
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

echo "=== [3/3] Running Bremen-MSS 2D benchmark ==="

METHOD_CONFIG="kaze.kaze_nfeatures=$KAZE_NFEATURES kaze.kaze_n_octave_layers=$KAZE_N_OCTAVE_LAYERS kaze.kaze_contrast_threshold=$KAZE_CONTRAST_THRESHOLD kaze.kaze_edge_threshold=$KAZE_EDGE_THRESHOLD kaze.kaze_sigma=$KAZE_SIGMA kaze.kaze_ratio_threshold=$KAZE_RATIO_THRESHOLD kaze.kaze_ransac_threshold=$KAZE_RANSAC_THRESHOLD kaze.kaze_ransac_confidence=$KAZE_RANSAC_CONFIDENCE kaze.kaze_extended=$KAZE_EXTENDED kaze.kaze_upright=$KAZE_UPRIGHT"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/bremenmss2d/docker-entrypoint-benchmark-bremenmss2d.sh \
    --method kaze \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$KAZE_N" \
    --radius "$KAZE_RADIUS" \
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
