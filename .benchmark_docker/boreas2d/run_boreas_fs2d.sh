#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Boreas 2D Benchmark Runner — FS2D method
#
# Convenience script that builds the Docker image + workspace and runs the
# Boreas 2D benchmark inside a container.
#
# Usage:
#   bash .benchmark_docker/boreas2d/run_boreas_fs2d.sh [num_workers] [options]
#
# Examples:
#   # All 46 sequences, 4 workers
#   bash .benchmark_docker/boreas2d/run_boreas_fs2d.sh 4
#
#   # Sequences 0-15 on machine 1
#   bash .benchmark_docker/boreas2d/run_boreas_fs2d.sh 4 --sequences 0-15
#
#   # Specific params
#   bash .benchmark_docker/boreas2d/run_boreas_fs2d.sh 8 --N 256 \
#       --size_of_pixel 0.25 --sequences all
#
#   # Quick test
#   bash .benchmark_docker/boreas2d/run_boreas_fs2d.sh 2 --test
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=4
TEST_MODE=""

# Extra args for the entry point
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) EXTRA_ARGS+=("--N" "$2"); shift 2 ;;
    --size_of_pixel) EXTRA_ARGS+=("--size_of_pixel" "$2"); shift 2 ;;
    --matching_step) EXTRA_ARGS+=("--matching_step" "$2"); shift 2 ;;
    --start_frame) EXTRA_ARGS+=("--start_frame" "$2"); shift 2 ;;
    --max_frames) EXTRA_ARGS+=("--max_frames" "$2"); shift 2 ;;
    --method-config) EXTRA_ARGS+=("--method-config" "$2"); shift 2 ;;
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
LOG_FILE="${RESULTS_DIR}/run_boreas2d_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE" 2>&1)

echo "=============================================="
echo "  Boreas 2D Benchmark — FS2D"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "Extra args:  ${EXTRA_ARGS[*]:-none}"
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

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/boreas2d/docker-entrypoint-benchmark-boreas2d.sh \
    --method fs2d \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    ${TEST_MODE:+--test} \
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
