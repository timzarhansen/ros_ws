#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Boreas 2D Benchmark Runner — NDT_P2D method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=4
TEST_MODE=""

# NDT defaults (from paramBenchMethods/boreasBenchmarkNDTSweep.py)
NDT_N=256
NDT_RADIUS=140.0
NDT_MATCHING_STEP=3
NDT_VOXEL_SIZE=15.0
NDT_STEP_SIZE=1.0
NDT_MAX_ITERATION=50
NDT_TRANSFORMATION_EPSILON=0.01
NDT_SCALE=1.0
NDT_THRESHOLD_PCT=5.0
NDT_Z_SCALE=0.1
NDT_USE_RAW_POINTCLOUD=true
NDT_RAW_INTENSITY_THRESHOLD=0.3

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) NDT_N="$2"; shift 2 ;;
    --radius) NDT_RADIUS="$2"; shift 2 ;;
    --matching_step) NDT_MATCHING_STEP="$2"; shift 2 ;;
    --start_frame) EXTRA_ARGS+=("--start_frame" "$2"); shift 2 ;;
    --max_frames) EXTRA_ARGS+=("--max_frames" "$2"); shift 2 ;;
    --ndt-voxel-size) NDT_VOXEL_SIZE="$2"; shift 2 ;;
    --ndt-step-size) NDT_STEP_SIZE="$2"; shift 2 ;;
    --ndt-max-iteration) NDT_MAX_ITERATION="$2"; shift 2 ;;
    --ndt-transformation-epsilon) NDT_TRANSFORMATION_EPSILON="$2"; shift 2 ;;
    --ndt-scale) NDT_SCALE="$2"; shift 2 ;;
    --ndt-threshold-pct) NDT_THRESHOLD_PCT="$2"; shift 2 ;;
    --ndt-z-scale) NDT_Z_SCALE="$2"; shift 2 ;;
    --use-raw-pointcloud) NDT_USE_RAW_POINTCLOUD="$2"; shift 2 ;;
    --raw-intensity-threshold) NDT_RAW_INTENSITY_THRESHOLD="$2"; shift 2 ;;
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
LOG_FILE="${RESULTS_DIR}/run_boreas2d_${TIMESTAMP}_ndt_p2d.log"

echo "=============================================="
echo "  Boreas 2D Benchmark — NDT_P2D"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $NDT_N"
echo "Radius:      $NDT_RADIUS"
echo "Match step:  $NDT_MATCHING_STEP"
echo "NDT params:  voxel_size=$NDT_VOXEL_SIZE step_size=$NDT_STEP_SIZE"
echo "             max_iter=$NDT_MAX_ITERATION eps=$NDT_TRANSFORMATION_EPSILON"
echo "             scale=$NDT_SCALE threshold_pct=$NDT_THRESHOLD_PCT z_scale=$NDT_Z_SCALE"
echo "Raw PC:      $NDT_USE_RAW_POINTCLOUD (threshold=$NDT_RAW_INTENSITY_THRESHOLD)"
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

METHOD_CONFIG="ndt_p2d.ndt_voxel_size=$NDT_VOXEL_SIZE ndt_p2d.ndt_step_size=$NDT_STEP_SIZE ndt_p2d.ndt_max_iteration=$NDT_MAX_ITERATION ndt_p2d.ndt_transformation_epsilon=$NDT_TRANSFORMATION_EPSILON ndt_p2d.ndt_scale=$NDT_SCALE ndt_p2d.ndt_threshold_pct=$NDT_THRESHOLD_PCT ndt_p2d.ndt_z_scale=$NDT_Z_SCALE"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/boreas2d/docker-entrypoint-benchmark-boreas2d.sh \
    --method ndt_p2d \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$NDT_N" \
    --radius "$NDT_RADIUS" \
    --matching_step "$NDT_MATCHING_STEP" \
    ${TEST_MODE:+--test} \
    --method-config "$METHOD_CONFIG" \
    $( [ "$NDT_USE_RAW_POINTCLOUD" = "true" ] && echo "--use-raw-pointcloud" ) \
    --raw-intensity-threshold "$NDT_RAW_INTENSITY_THRESHOLD" \
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
