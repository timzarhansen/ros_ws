#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Boreas 2D Benchmark Runner — ICP method
#
# Convenience script that builds the Docker image + workspace and runs the
# Boreas 2D benchmark inside a container.
#
# Usage:
#   bash .benchmark_docker/boreas2d/run_boreas_icp.sh [num_workers] [options]
#
# Examples:
#   # All 46 sequences, 4 workers
#   bash .benchmark_docker/boreas2d/run_boreas_icp.sh 4
#
#   # Sequences 0-15 on machine 1
#   bash .benchmark_docker/boreas2d/run_boreas_icp.sh 4 --sequences 0-15
#
#   # Custom ICP params
#   bash .benchmark_docker/boreas2d/run_boreas_icp.sh 8 --N 256 \
#       --radius 140.0 --sequences all --icp-voxel-size 1.5
#
#   # Quick test
#   bash .benchmark_docker/boreas2d/run_boreas_icp.sh 2 --test
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=4
TEST_MODE=""

# ICP defaults (from paramBenchMethods/boreasBenchmarkICPSweep.py)
ICP_N=256
ICP_RADIUS=140.0
ICP_MATCHING_STEP=3
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
    --matching_step) ICP_MATCHING_STEP="$2"; shift 2 ;;
    --start_frame) EXTRA_ARGS+=("--start_frame" "$2"); shift 2 ;;
    --max_frames) EXTRA_ARGS+=("--max_frames" "$2"); shift 2 ;;
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

# === Data dir ===
DATA_DIR="${DATA_DIR:-/home/tim-external/dataFolder/radar_boreas}"

# === Logging ===
RESULTS_DIR="benchmark_results/boreas2d"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${RESULTS_DIR}/run_boreas2d_${TIMESTAMP}_icp.log"

echo "=============================================="
echo "  Boreas 2D Benchmark — ICP"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $ICP_N"
echo "Radius:      $ICP_RADIUS"
echo "Match step:  $ICP_MATCHING_STEP"
echo "ICP params:  max_distance=$ICP_MAX_DISTANCE max_iter=$ICP_MAX_ITERATION"
echo "             scale=$ICP_SCALE threshold_pct=$ICP_THRESHOLD_PCT voxel_size=$ICP_VOXEL_SIZE"
echo "Raw PC:      $ICP_USE_RAW_POINTCLOUD (threshold=$ICP_RAW_INTENSITY_THRESHOLD)"
echo ""

# === Step 1: Build image (if needed) ===
if ! docker image inspect fsbench:latest >/dev/null 2>&1; then
  echo "=== [1/3] Building docker image ==="
  docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
  echo ""
else
  echo "=== Docker image fsbench:latest already exists ==="
fi

# === Step 2: Build workspace (if needed) ===
if [ ! -d "install/soft20" ]; then
  echo "=== [2/3] Building workspace ==="
  docker run --rm \
    -v "$(pwd):/home/benchmark/ros_ws" \
    fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
  echo ""
else
  echo "=== Workspace already built (install/soft20 exists) ==="
fi

# === Step 3: Run benchmark ===
echo "=== [3/3] Running Boreas 2D benchmark ==="

# Build method config
METHOD_CONFIG="icp.icp_max_distance=$ICP_MAX_DISTANCE icp.icp_max_iteration=$ICP_MAX_ITERATION icp.icp_scale=$ICP_SCALE icp.icp_threshold_pct=$ICP_THRESHOLD_PCT icp.icp_voxel_size=$ICP_VOXEL_SIZE"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/boreas2d/docker-entrypoint-benchmark-boreas2d.sh \
    --method icp \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$ICP_N" \
    --radius "$ICP_RADIUS" \
    --matching_step "$ICP_MATCHING_STEP" \
    ${TEST_MODE:+--test} \
    --method-config "$METHOD_CONFIG" \
    $( [ "$ICP_USE_RAW_POINTCLOUD" = "true" ] && echo "--use-raw-pointcloud" ) \
    --raw-intensity-threshold "$ICP_RAW_INTENSITY_THRESHOLD" \
    "${EXTRA_ARGS[@]}" \
    /data

EXIT_CODE=$?

# === Summary ===
echo ""
echo "=============================================="
echo "  Benchmark complete (exit code: $EXIT_CODE)"
echo "=============================================="
echo "Results: $(pwd)/${RESULTS_DIR}/"
ls -la "${RESULTS_DIR}/combined/"*.csv 2>/dev/null && echo "Combined summary available."
echo ""

exit $EXIT_CODE
