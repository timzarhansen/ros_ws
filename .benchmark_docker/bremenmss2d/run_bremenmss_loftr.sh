#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Bremen-MSS 2D Benchmark Runner — LoFTR method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=1
TEST_MODE=""

# LoFTR defaults
LOFTR_N=256
LOFTR_RADIUS=22.5
LOFTR_RANSAC_THRESHOLD=5.0
LOFTR_RANSAC_CONFIDENCE=0.99

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) LOFTR_N="$2"; shift 2 ;;
    --radius) LOFTR_RADIUS="$2"; shift 2 ;;
    --loftr-ransac-threshold) LOFTR_RANSAC_THRESHOLD="$2"; shift 2 ;;
    --loftr-ransac-confidence) LOFTR_RANSAC_CONFIDENCE="$2"; shift 2 ;;
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
LOG_FILE="${RESULTS_DIR}/run_bremenmss2d_${TIMESTAMP}_loftr.log"

echo "=============================================="
echo "  Bremen-MSS 2D Benchmark — LoFTR"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $LOFTR_N"
echo "Radius:      $LOFTR_RADIUS"
echo "LoFTR params: ransac_threshold=$LOFTR_RANSAC_THRESHOLD confidence=$LOFTR_RANSAC_CONFIDENCE"
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

METHOD_CONFIG="loftr.loftr_ransac_threshold=$LOFTR_RANSAC_THRESHOLD loftr.loftr_ransac_confidence=$LOFTR_RANSAC_CONFIDENCE"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/bremenmss2d/docker-entrypoint-benchmark-bremenmss2d.sh \
    --method loftr \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$LOFTR_N" \
    --radius "$LOFTR_RADIUS" \
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
