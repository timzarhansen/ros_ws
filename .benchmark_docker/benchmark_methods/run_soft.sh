#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

# === Method (embedded in script name) ===
METHOD="soft"

# === Parameters ===
NUM_WORKERS=14
TEST_MODE=""
SOFT_N=64
SOFT_USE_CLAHE=1
SOFT_R_MIN=""
SOFT_R_MAX=""
SOFT_LEVEL_ROTATION=0.001
SOFT_LEVEL_TRANSLATION=0.001
SOFT_NORMALIZATION=2
SOFT_NOISE_SUBSET=""
SOFT_R_MIN_EXPLICIT=false
SOFT_R_MAX_EXPLICIT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --soft-N) SOFT_N="$2"; shift 2 ;;
    --soft-r-min) SOFT_R_MIN="$2"; SOFT_R_MIN_EXPLICIT=true; shift 2 ;;
    --soft-r-max) SOFT_R_MAX="$2"; SOFT_R_MAX_EXPLICIT=true; shift 2 ;;
    --soft-level-rotation) SOFT_LEVEL_ROTATION="$2"; shift 2 ;;
    --soft-level-translation) SOFT_LEVEL_TRANSLATION="$2"; shift 2 ;;
    --soft-normalization) SOFT_NORMALIZATION="$2"; shift 2 ;;
    --soft-use-clahe) SOFT_USE_CLAHE="$2"; shift 2 ;;
    --soft-noise-subset) SOFT_NOISE_SUBSET="$2"; shift 2 ;;
    --test) TEST_MODE="--test"; shift ;;
    *) NUM_WORKERS="$1"; shift ;;
  esac
done

# Auto-derive r_min/r_max from N if not explicitly set
if [ "$SOFT_R_MIN_EXPLICIT" != "true" ]; then
    SOFT_R_MIN=$(( SOFT_N / 8 ))
fi
if [ "$SOFT_R_MAX_EXPLICIT" != "true" ]; then
    SOFT_R_MAX=$(( SOFT_N / 2 - SOFT_N / 8 ))
fi

# === Logging ===
mkdir -p test_results
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="test_results/run_${TIMESTAMP}_${METHOD}.log"
exec > >(tee -a "$LOG_FILE" 2>&1)

echo "=============================================="
echo "  Benchmark: ${METHOD}"
echo "=============================================="
echo "Log file: ${LOG_FILE}"
echo ""

# === Step 1: Build image ===
echo "=== Step 1: docker build ==="
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
echo ""

# === Step 2: Build workspace ===
echo "=== Step 2: docker build workspace ==="
docker run --rm -v $(pwd):/home/benchmark/ros_ws fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
echo ""

# === Step 3: Run benchmark ===
echo "=== Step 3: Run benchmark (${METHOD}, workers=${NUM_WORKERS}, N=${SOFT_N}) ==="
echo "SOFT params: r_min=${SOFT_R_MIN}, r_max=${SOFT_R_MAX}, level_rot=${SOFT_LEVEL_ROTATION}, level_trans=${SOFT_LEVEL_TRANSLATION}, norm=${SOFT_NORMALIZATION}, clahe=${SOFT_USE_CLAHE}${SOFT_NOISE_SUBSET:+, noise_subset=${SOFT_NOISE_SUBSET}}"
docker run --rm \
  -e SOFT_N="$SOFT_N" \
  -e SOFT_R_MIN="$SOFT_R_MIN" \
  -e SOFT_R_MAX="$SOFT_R_MAX" \
  -e SOFT_USE_CLAHE="$SOFT_USE_CLAHE" \
  -e SOFT_LEVEL_ROTATION="$SOFT_LEVEL_ROTATION" \
  -e SOFT_LEVEL_TRANSLATION="$SOFT_LEVEL_TRANSLATION" \
  -e SOFT_NORMALIZATION="$SOFT_NORMALIZATION" \
  -e SOFT_NOISE_SUBSET="$SOFT_NOISE_SUBSET" \
  -v $(pwd):/home/benchmark/ros_ws \
  -v $(pwd)/dataFolder:/data:ro \
  -v $(pwd)/weights:/volume/weights:ro \
  -v ./test_results/:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh ${METHOD} ${NUM_WORKERS} ${TEST_MODE}
echo ""

# === Step 4: Show results ===
echo "=============================================="
echo "  Results"
echo "=============================================="
ls -la ./test_results/${METHOD}/outfile_*.csv 2>/dev/null || echo "(no CSV files)"

echo ""
echo "=============================================="
echo "  DONE: ${METHOD}"
echo "=============================================="
