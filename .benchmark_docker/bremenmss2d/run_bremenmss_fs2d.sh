#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Bremen-MSS 2D Benchmark Runner — FS2D method
#
# Usage:
#   bash .benchmark_docker/bremenmss2d/run_bremenmss_fs2d.sh [num_workers] [options]
#
# Examples:
#   # All 13 sequences, 4 workers
#   bash .benchmark_docker/bremenmss2d/run_bremenmss_fs2d.sh 4
#
#   # Sequences 1-5 on machine 1
#   bash .benchmark_docker/bremenmss2d/run_bremenmss_fs2d.sh 4 --sequences 1-5
#
#   # Quick test
#   bash .benchmark_docker/bremenmss2d/run_bremenmss_fs2d.sh 2 --test
# ============================================================================

cd "$(dirname "$0")/../.."

# === Defaults ===
NUM_WORKERS=1
TEST_MODE=""

# FS2D defaults
FS2D_N=256
FS2D_RADIUS=22.5
FS2D_POTENTIAL_FOR_NECESSARY_PEAK=0.01
FS2D_LEVEL_POTENTIAL_ROTATION=0.001
FS2D_USE_DIRECT=true
FS2D_USE_CLACHE=false
FS2D_USE_HAMMING=true
FS2D_MULTIPLE_RADII=true
FS2D_USE_GAUSS=false
FS2D_NORMALIZATION=1
FS2D_USE_WEIGHTED_PEAK_SCORE=true
FS2D_USE_PHASE_CORRELATION=false

EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --sequences) EXTRA_ARGS+=("--sequences" "$2"); shift 2 ;;
    --N) FS2D_N="$2"; shift 2 ;;
    --radius) FS2D_RADIUS="$2"; shift 2 ;;
    --potential_for_necessary_peak) FS2D_POTENTIAL_FOR_NECESSARY_PEAK="$2"; shift 2 ;;
    --level_potential_rotation) FS2D_LEVEL_POTENTIAL_ROTATION="$2"; shift 2 ;;
    --use-direct) FS2D_USE_DIRECT="$2"; shift 2 ;;
    --use-clahe) FS2D_USE_CLACHE="$2"; shift 2 ;;
    --use-hamming) FS2D_USE_HAMMING="$2"; shift 2 ;;
    --multiple-radii) FS2D_MULTIPLE_RADII="$2"; shift 2 ;;
    --use-gauss) FS2D_USE_GAUSS="$2"; shift 2 ;;
    --normalization) FS2D_NORMALIZATION="$2"; shift 2 ;;
    --use-weighted-peak-score) FS2D_USE_WEIGHTED_PEAK_SCORE="$2"; shift 2 ;;
    --use-phase-correlation) FS2D_USE_PHASE_CORRELATION="$2"; shift 2 ;;
    --save-blended) EXTRA_ARGS+=("--save-blended"); shift ;;
    --output-dir) EXTRA_ARGS+=("--output-dir" "$2"); shift 2 ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    *) NUM_WORKERS="$1"; shift ;;
  esac
done

# === Data dir ===
DATA_DIR="${DATA_DIR:-/home/tim-external/dataFolder/Bremen-MSS-Processed}"

# === Logging ===
RESULTS_DIR="benchmark_results/bremenmss2d"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${RESULTS_DIR}/run_bremenmss2d_${TIMESTAMP}_fs2d.log"

echo "=============================================="
echo "  Bremen-MSS 2D Benchmark — FS2D"
echo "=============================================="
echo "Started:     $(date)"
echo "Workers:     $NUM_WORKERS"
echo "Data dir:    $DATA_DIR"
echo "Results dir: $RESULTS_DIR"
echo "Log file:    $LOG_FILE"
echo "Test mode:   ${TEST_MODE:-no}"
echo "N:           $FS2D_N"
echo "Radius:      $FS2D_RADIUS"
echo "FS2D params: use_clahe=$FS2D_USE_CLACHE use_hamming=$FS2D_USE_HAMMING"
echo "             use_direct=$FS2D_USE_DIRECT use_gauss=$FS2D_USE_GAUSS"
echo "             multiple_radii=$FS2D_MULTIPLE_RADII"
echo "             potential_peak=$FS2D_POTENTIAL_FOR_NECESSARY_PEAK"
echo "             level_rot=$FS2D_LEVEL_POTENTIAL_ROTATION"
echo "             normalization=$FS2D_NORMALIZATION"
echo "             weighted_peak=$FS2D_USE_WEIGHTED_PEAK_SCORE"
echo "             phase_corr=$FS2D_USE_PHASE_CORRELATION"
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
echo "=== [3/3] Running Bremen-MSS 2D benchmark ==="

METHOD_CONFIG="fs2d.potential_for_necessary_peak=$FS2D_POTENTIAL_FOR_NECESSARY_PEAK fs2d.level_potential_rotation=$FS2D_LEVEL_POTENTIAL_ROTATION fs2d.use_direct=$FS2D_USE_DIRECT fs2d.use_clahe=$FS2D_USE_CLACHE fs2d.use_hamming=$FS2D_USE_HAMMING fs2d.multiple_radii=$FS2D_MULTIPLE_RADII fs2d.use_gauss=$FS2D_USE_GAUSS fs2d.normalization=$FS2D_NORMALIZATION fs2d.use_weighted_peak_score=$FS2D_USE_WEIGHTED_PEAK_SCORE fs2d.use_phase_correlation=$FS2D_USE_PHASE_CORRELATION"

docker run --rm \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$DATA_DIR:/data:ro" \
  -v "$(pwd)/${RESULTS_DIR}:/volume/results" \
  fsbench:latest \
  bash /home/benchmark/ros_ws/.benchmark_docker/bremenmss2d/docker-entrypoint-benchmark-bremenmss2d.sh \
    --method fs2d \
    --num-workers "$NUM_WORKERS" \
    --output-dir /volume/results \
    --N "$FS2D_N" \
    --radius "$FS2D_RADIUS" \
    ${TEST_MODE:+--test} \
    --method-config "$METHOD_CONFIG" \
    "${EXTRA_ARGS[@]}" \
    /data

EXIT_CODE=$?

# === Summary ===
echo ""
echo "=============================================="
echo "  Benchmark complete (exit code: $EXIT_CODE)"
echo "=============================================="
echo "Results: $(pwd)/${RESULTS_DIR}/"
echo ""

exit $EXIT_CODE
