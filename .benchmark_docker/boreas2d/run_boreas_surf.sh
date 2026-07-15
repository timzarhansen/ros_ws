#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Boreas 2D Benchmark Runner — SURF method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=4
TEST_MODE=""

# SURF defaults (from paramBenchMethods/boreasBenchmarkSURFSweep.py)
SURF_N=128
SURF_RADIUS=140.0
SURF_MATCHING_STEP=3
SURF_HESSIAN_THRESHOLD=400
SURF_N_OCTAVES=4
SURF_N_OCTAVE_LAYERS=3
SURF_EXTENDED=true
SURF_UPRIGHT=false
SURF_RATIO_THRESHOLD=0.75
SURF_RANSAC_THRESHOLD=3.0
SURF_RANSAC_CONFIDENCE=0.99

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) SURF_N="$2"; shift 2 ;;
    --radius) SURF_RADIUS="$2"; shift 2 ;;
    --matching_step) SURF_MATCHING_STEP="$2"; shift 2 ;;
    --start_frame) EXTRA_ARGS+=("--start_frame" "$2"); shift 2 ;;
    --max_frames) EXTRA_ARGS+=("--max_frames" "$2"); shift 2 ;;
    --surf-hessian-threshold) SURF_HESSIAN_THRESHOLD="$2"; shift 2 ;;
    --surf-n-octaves) SURF_N_OCTAVES="$2"; shift 2 ;;
    --surf-n-octave-layers) SURF_N_OCTAVE_LAYERS="$2"; shift 2 ;;
    --surf-extended) SURF_EXTENDED="$2"; shift 2 ;;
    --surf-upright) SURF_UPRIGHT="$2"; shift 2 ;;
    --surf-ratio-threshold) SURF_RATIO_THRESHOLD="$2"; shift 2 ;;
    --surf-ransac-threshold) SURF_RANSAC_THRESHOLD="$2"; shift 2 ;;
    --surf-ransac-confidence) SURF_RANSAC_CONFIDENCE="$2"; shift 2 ;;
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
LOG_FILE="${RESULTS_DIR}/run_boreas2d_${TIMESTAMP}_surf.log"
exec > >(tee -a "$LOG_FILE" 2>&1)

echo "=============================================="
echo "  Boreas 2D Benchmark — SURF"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $SURF_N"
echo "Radius:      $SURF_RADIUS"
echo "Match step:  $SURF_MATCHING_STEP"
echo "SURF params: hessian=$SURF_HESSIAN_THRESHOLD n_octaves=$SURF_N_OCTAVES"
echo "             n_octave_layers=$SURF_N_OCTAVE_LAYERS extended=$SURF_EXTENDED"
echo "             upright=$SURF_UPRIGHT ratio_threshold=$SURF_RATIO_THRESHOLD"
echo "             ransac_threshold=$SURF_RANSAC_THRESHOLD confidence=$SURF_RANSAC_CONFIDENCE"
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

METHOD_CONFIG="surf.surf_hessian_threshold=$SURF_HESSIAN_THRESHOLD surf.surf_n_octaves=$SURF_N_OCTAVES surf.surf_n_octave_layers=$SURF_N_OCTAVE_LAYERS surf.surf_extended=$SURF_EXTENDED surf.surf_upright=$SURF_UPRIGHT surf.surf_ratio_threshold=$SURF_RATIO_THRESHOLD surf.surf_ransac_threshold=$SURF_RANSAC_THRESHOLD surf.surf_ransac_confidence=$SURF_RANSAC_CONFIDENCE"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/boreas2d/docker-entrypoint-benchmark-boreas2d.sh \
    --method surf \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$SURF_N" \
    --radius "$SURF_RADIUS" \
    --matching_step "$SURF_MATCHING_STEP" \
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
