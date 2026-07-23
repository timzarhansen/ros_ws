#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Bremen-MSS 2D Benchmark Runner — NDT P2D method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=1
TEST_MODE=""

# NDT P2D defaults
NDT_N=256
NDT_RADIUS=22.5
NDT_VOXEL_SIZE=1.0
NDT_STEP_SIZE=0.1
NDT_EPSILON=0.01
NDT_MAX_ITERATION=100
NDT_SCALE=1.0
NDT_THRESHOLD_PCT=10.0

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) NDT_N="$2"; shift 2 ;;
    --radius) NDT_RADIUS="$2"; shift 2 ;;
    --ndt-voxel-size) NDT_VOXEL_SIZE="$2"; shift 2 ;;
    --ndt-step-size) NDT_STEP_SIZE="$2"; shift 2 ;;
    --ndt-epsilon) NDT_EPSILON="$2"; shift 2 ;;
    --ndt-max-iteration) NDT_MAX_ITERATION="$2"; shift 2 ;;
    --ndt-scale) NDT_SCALE="$2"; shift 2 ;;
    --ndt-threshold-pct) NDT_THRESHOLD_PCT="$2"; shift 2 ;;
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
LOG_FILE="${RESULTS_DIR}/run_bremenmss2d_${TIMESTAMP}_ndt_p2d.log"

echo "=============================================="
echo "  Bremen-MSS 2D Benchmark — NDT P2D"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $NDT_N"
echo "Radius:      $NDT_RADIUS"
echo "NDT params:  voxel_size=$NDT_VOXEL_SIZE step_size=$NDT_STEP_SIZE"
echo "             epsilon=$NDT_EPSILON max_iter=$NDT_MAX_ITERATION"
echo "             scale=$NDT_SCALE threshold_pct=$NDT_THRESHOLD_PCT"
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

METHOD_CONFIG="ndt_p2d.ndt_voxel_size=$NDT_VOXEL_SIZE ndt_p2d.ndt_step_size=$NDT_STEP_SIZE ndt_p2d.ndt_epsilon=$NDT_EPSILON ndt_p2d.ndt_max_iteration=$NDT_MAX_ITERATION ndt_p2d.ndt_scale=$NDT_SCALE ndt_p2d.ndt_threshold_pct=$NDT_THRESHOLD_PCT"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/bremenmss2d/docker-entrypoint-benchmark-bremenmss2d.sh \
    --method ndt_p2d \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$NDT_N" \
    --radius "$NDT_RADIUS" \
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
