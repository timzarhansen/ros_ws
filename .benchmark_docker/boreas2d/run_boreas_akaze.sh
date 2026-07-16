#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Boreas 2D Benchmark Runner — AKAZE method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=4
TEST_MODE=""

# AKAZE defaults (from paramBenchMethods/boreasBenchmarkAKAZESweep.py)
AKAZE_N=256
AKAZE_RADIUS=140.0
AKAZE_MATCHING_STEP=3
AKAZE_DESCRIPTOR_TYPE=MLDB
AKAZE_DESCRIPTOR_SIZE=0
AKAZE_DESCRIPTOR_CHANNELS=3
AKAZE_THRESHOLD=0.0001
AKAZE_N_OCTAVES=4
AKAZE_N_OCTAVE_LAYERS=4
AKAZE_DIFFUSIVITY=1
AKAZE_RATIO_THRESHOLD=0.6
AKAZE_RANSAC_THRESHOLD=1.0
AKAZE_RANSAC_CONFIDENCE=0.99

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) AKAZE_N="$2"; shift 2 ;;
    --radius) AKAZE_RADIUS="$2"; shift 2 ;;
    --matching_step) AKAZE_MATCHING_STEP="$2"; shift 2 ;;
    --start_frame) EXTRA_ARGS+=("--start_frame" "$2"); shift 2 ;;
    --max_frames) EXTRA_ARGS+=("--max_frames" "$2"); shift 2 ;;
    --akaze-descriptor-type) AKAZE_DESCRIPTOR_TYPE="$2"; shift 2 ;;
    --akaze-descriptor-size) AKAZE_DESCRIPTOR_SIZE="$2"; shift 2 ;;
    --akaze-descriptor-channels) AKAZE_DESCRIPTOR_CHANNELS="$2"; shift 2 ;;
    --akaze-threshold) AKAZE_THRESHOLD="$2"; shift 2 ;;
    --akaze-n-octaves) AKAZE_N_OCTAVES="$2"; shift 2 ;;
    --akaze-n-octave-layers) AKAZE_N_OCTAVE_LAYERS="$2"; shift 2 ;;
    --akaze-diffusivity) AKAZE_DIFFUSIVITY="$2"; shift 2 ;;
    --akaze-ratio-threshold) AKAZE_RATIO_THRESHOLD="$2"; shift 2 ;;
    --akaze-ransac-threshold) AKAZE_RANSAC_THRESHOLD="$2"; shift 2 ;;
    --akaze-ransac-confidence) AKAZE_RANSAC_CONFIDENCE="$2"; shift 2 ;;
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
LOG_FILE="${RESULTS_DIR}/run_boreas2d_${TIMESTAMP}_akaze.log"

echo "=============================================="
echo "  Boreas 2D Benchmark — AKAZE"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $AKAZE_N"
echo "Radius:      $AKAZE_RADIUS"
echo "Match step:  $AKAZE_MATCHING_STEP"
echo "AKAZE params: descriptor_type=$AKAZE_DESCRIPTOR_TYPE"
echo "             descriptor_size=$AKAZE_DESCRIPTOR_SIZE channels=$AKAZE_DESCRIPTOR_CHANNELS"
echo "             threshold=$AKAZE_THRESHOLD n_octaves=$AKAZE_N_OCTAVES"
echo "             n_octave_layers=$AKAZE_N_OCTAVE_LAYERS diffusivity=$AKAZE_DIFFUSIVITY"
echo "             ratio_threshold=$AKAZE_RATIO_THRESHOLD"
echo "             ransac_threshold=$AKAZE_RANSAC_THRESHOLD confidence=$AKAZE_RANSAC_CONFIDENCE"
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

METHOD_CONFIG="akaze.akaze_descriptor_type=$AKAZE_DESCRIPTOR_TYPE akaze.akaze_descriptor_size=$AKAZE_DESCRIPTOR_SIZE akaze.akaze_descriptor_channels=$AKAZE_DESCRIPTOR_CHANNELS akaze.akaze_threshold=$AKAZE_THRESHOLD akaze.akaze_n_octaves=$AKAZE_N_OCTAVES akaze.akaze_n_octave_layers=$AKAZE_N_OCTAVE_LAYERS akaze.akaze_diffusivity=$AKAZE_DIFFUSIVITY akaze.akaze_ratio_threshold=$AKAZE_RATIO_THRESHOLD akaze.akaze_ransac_threshold=$AKAZE_RANSAC_THRESHOLD akaze.akaze_ransac_confidence=$AKAZE_RANSAC_CONFIDENCE"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/boreas2d/docker-entrypoint-benchmark-boreas2d.sh \
    --method akaze \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$AKAZE_N" \
    --radius "$AKAZE_RADIUS" \
    --matching_step "$AKAZE_MATCHING_STEP" \
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
