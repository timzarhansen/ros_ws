#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Bremen-MSS 2D Benchmark Runner — EfficientLoFTR method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=1
TEST_MODE=""

# EfficientLoFTR defaults
ELOFTR_N=256
ELOFTR_RADIUS=22.5
ELOFTR_WEIGHT_PATH="/volume/weights/eloftr/eloftr.ckpt"
ELOFTR_RESOLUTION=4
ELOFTR_CONFIDENCE=0.5

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) ELOFTR_N="$2"; shift 2 ;;
    --radius) ELOFTR_RADIUS="$2"; shift 2 ;;
    --eloftr-weight-path) ELOFTR_WEIGHT_PATH="$2"; shift 2 ;;
    --eloftr-resolution) ELOFTR_RESOLUTION="$2"; shift 2 ;;
    --eloftr-confidence) ELOFTR_CONFIDENCE="$2"; shift 2 ;;
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
LOG_FILE="${RESULTS_DIR}/run_bremenmss2d_${TIMESTAMP}_eloftr.log"

echo "=============================================="
echo "  Bremen-MSS 2D Benchmark — EfficientLoFTR"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $ELOFTR_N"
echo "Radius:      $ELOFTR_RADIUS"
echo "Eff. LoFTR params: resolution=$ELOFTR_RESOLUTION confidence=$ELOFTR_CONFIDENCE"
echo "                   weight_path=$ELOFTR_WEIGHT_PATH"
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

METHOD_CONFIG="eloftr.eloftr_resolution=$ELOFTR_RESOLUTION eloftr.eloftr_confidence=$ELOFTR_CONFIDENCE"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  ${ELOFTR_WEIGHT_PATH:+ -v "$(dirname "$ELOFTR_WEIGHT_PATH"):/volume/weights/eloftr:ro"} \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/bremenmss2d/docker-entrypoint-benchmark-bremenmss2d.sh \
    --method eloftr \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$ELOFTR_N" \
    --radius "$ELOFTR_RADIUS" \
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
