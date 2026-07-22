#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Bremen-MSS 2D Benchmark Runner — SURF method
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=4
TEST_MODE=""

# SURF defaults
SURF_N=256
SURF_RADIUS=22.5
SURF_NFEATURES=0
SURF_N_OCTAVE_LAYERS=3
SURF_CONTRAST_THRESHOLD=0.01
SURF_EDGE_THRESHOLD=10
SURF_SIGMA=1.2
SURF_RATIO_THRESHOLD=0.6
SURF_RANSAC_THRESHOLD=1.0
SURF_RANSAC_CONFIDENCE=0.99

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) SURF_N="$2"; shift 2 ;;
    --radius) SURF_RADIUS="$2"; shift 2 ;;
    --surf-nfeatures) SURF_NFEATURES="$2"; shift 2 ;;
    --surf-n-octave-layers) SURF_N_OCTAVE_LAYERS="$2"; shift 2 ;;
    --surf-contrast-threshold) SURF_CONTRAST_THRESHOLD="$2"; shift 2 ;;
    --surf-edge-threshold) SURF_EDGE_THRESHOLD="$2"; shift 2 ;;
    --surf-sigma) SURF_SIGMA="$2"; shift 2 ;;
    --surf-ratio-threshold) SURF_RATIO_THRESHOLD="$2"; shift 2 ;;
    --surf-ransac-threshold) SURF_RANSAC_THRESHOLD="$2"; shift 2 ;;
    --surf-ransac-confidence) SURF_RANSAC_CONFIDENCE="$2"; shift 2 ;;
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
LOG_FILE="${RESULTS_DIR}/run_bremenmss2d_${TIMESTAMP}_surf.log"

echo "=============================================="
echo "  Bremen-MSS 2D Benchmark — SURF"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $SURF_N"
echo "Radius:      $SURF_RADIUS"
echo "SURF params: nfeatures=$SURF_NFEATURES n_octave_layers=$SURF_N_OCTAVE_LAYERS"
echo "             contrast_threshold=$SURF_CONTRAST_THRESHOLD edge_threshold=$SURF_EDGE_THRESHOLD"
echo "             sigma=$SURF_SIGMA ratio_threshold=$SURF_RATIO_THRESHOLD"
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

echo "=== [3/3] Running Bremen-MSS 2D benchmark ==="

METHOD_CONFIG="surf.surf_nfeatures=$SURF_NFEATURES surf.surf_n_octave_layers=$SURF_N_OCTAVE_LAYERS surf.surf_contrast_threshold=$SURF_CONTRAST_THRESHOLD surf.surf_edge_threshold=$SURF_EDGE_THRESHOLD surf.surf_sigma=$SURF_SIGMA surf.surf_ratio_threshold=$SURF_RATIO_THRESHOLD surf.surf_ransac_threshold=$SURF_RANSAC_THRESHOLD surf.surf_ransac_confidence=$SURF_RANSAC_CONFIDENCE"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/bremenmss2d/docker-entrypoint-benchmark-bremenmss2d.sh \
    --method surf \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$SURF_N" \
    --radius "$SURF_RADIUS" \
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
