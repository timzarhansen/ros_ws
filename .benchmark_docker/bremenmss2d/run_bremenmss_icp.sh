#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Bremen-MSS 2D Benchmark Runner — ICP method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=4
TEST_MODE=""

# ICP defaults
ICP_N=256
ICP_RADIUS=22.5
ICP_MAX_DISTANCE=10.0
ICP_MAX_ITERATION=200
ICP_SCALE=1.0
ICP_THRESHOLD_PCT=10.0
ICP_VOXEL_SIZE=1.0
ICP_USE_RAW_POINTCLOUD=true
ICP_RAW_INTENSITY_THRESHOLD=0.3

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) ICP_N="$2"; shift 2 ;;
    --radius) ICP_RADIUS="$2"; shift 2 ;;
    --icp-max-distance) ICP_MAX_DISTANCE="$2"; shift 2 ;;
    --icp-max-iteration) ICP_MAX_ITERATION="$2"; shift 2 ;;
    --icp-scale) ICP_SCALE="$2"; shift 2 ;;
    --icp-threshold-pct) ICP_THRESHOLD_PCT="$2"; shift 2 ;;
    --icp-voxel-size) ICP_VOXEL_SIZE="$2"; shift 2 ;;
    --use-raw-pointcloud) ICP_USE_RAW_POINTCLOUD="$2"; shift 2 ;;
    --raw-intensity-threshold) ICP_RAW_INTENSITY_THRESHOLD="$2"; shift 2 ;;
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
LOG_FILE="${RESULTS_DIR}/run_bremenmss2d_${TIMESTAMP}_icp.log"

echo "=============================================="
echo "  Bremen-MSS 2D Benchmark — ICP"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $ICP_N"
echo "Radius:      $ICP_RADIUS"
echo "ICP params:  max_distance=$ICP_MAX_DISTANCE max_iter=$ICP_MAX_ITERATION"
echo "             scale=$ICP_SCALE threshold_pct=$ICP_THRESHOLD_PCT voxel_size=$ICP_VOXEL_SIZE"
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

METHOD_CONFIG="icp.icp_max_distance=$ICP_MAX_DISTANCE icp.icp_max_iteration=$ICP_MAX_ITERATION icp.icp_scale=$ICP_SCALE icp.icp_threshold_pct=$ICP_THRESHOLD_PCT icp.icp_voxel_size=$ICP_VOXEL_SIZE"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/bremenmss2d/docker-entrypoint-benchmark-bremenmss2d.sh \
    --method icp \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$ICP_N" \
    --radius "$ICP_RADIUS" \
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
