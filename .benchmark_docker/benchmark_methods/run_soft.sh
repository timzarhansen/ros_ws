#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."

# === Method (embedded in script name) ===
METHOD="soft"

# === Parameters ===
NUM_WORKERS=8
TEST_MODE=""
SOFT_N=32

while [[ $# -gt 0 ]]; do
  case $1 in
    --soft-N) SOFT_N="$2"; shift 2 ;;
    --test)   TEST_MODE="--test"; shift ;;
    *)        NUM_WORKERS="$1"; shift ;;
  esac
done

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
docker run --rm \
  -v $(pwd):/home/benchmark/ros_ws \
  -v $(pwd)/dataFolder:/data:ro \
  -v $(pwd)/weights:/volume/weights:ro \
  -v ./test_results/:/volume/results \
  fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh ${METHOD} ${NUM_WORKERS} ${TEST_MODE} ${SOFT_N}
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
