#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Lidar Simulation 2D Benchmark Runner — ndt_p2d method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=1
TEST_MODE=""

# ndt_p2d defaults
ndt_p2d_N=256
ndt_p2d_RADIUS=15.0
NDT_P2D_STEP_SIZE=0.1
NDT_P2D_NDT_RESOLUTION=1.0
NDT_P2D_MAX_ITERATIONS=35
NDT_P2D_TRANSFORMATION_EPSILON=0.01

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) ndt_p2d_N="$2"; shift 2 ;;
    --radius) ndt_p2d_RADIUS="$2"; shift 2 ;;
    --ndt-step-size) NDT_P2D_STEP_SIZE="$2"; shift 2 ;;
    --ndt-ndt-resolution) NDT_P2D_NDT_RESOLUTION="$2"; shift 2 ;;
    --ndt-max-iterations) NDT_P2D_MAX_ITERATIONS="$2"; shift 2 ;;
    --ndt-transformation-epsilon) NDT_P2D_TRANSFORMATION_EPSILON="$2"; shift 2 ;;
    --save-blended) EXTRA_ARGS+=("--save-blended"); shift ;;
    --output-dir) EXTRA_ARGS+=("--output-dir" "$2"); shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    *) NUM_WORKERS="$1"; shift ;;
  esac
done

DATA_DIR="${DATA_DIR:-/home/tim-external/dataFolder/simulation_gazebo_scans}"

RESULTS_DIR="benchmark_results/simulation_gazebo_scans"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${RESULTS_DIR}/run_sim_gazebo_${TIMESTAMP}_ndt_p2d.log"

echo "=============================================="
echo "  Lidar Simulation 2D Benchmark — ndt_p2d"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           ${ndt_p2d_N}"
echo "Radius:      ${ndt_p2d_RADIUS}"
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

METHOD_CONFIG="ndt_p2d.step_size=0.1 ndt_p2d.ndt_resolution=1.0 ndt_p2d.max_iterations=35 ndt_p2d.transformation_epsilon=0.01"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/simulation_gazebo_scans/\
docker-entrypoint-benchmark-simulation_gazebo_scans.sh \
    --method ndt_p2d \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "${ndt_p2d_N}" \
    --radius "${ndt_p2d_RADIUS}" \
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
