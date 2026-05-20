#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=============================================="
echo "  fsregistration Docker Test Runner"
echo "=============================================="
echo ""

# === Step 1: Pull latest ===
echo "=== Step 1: git pull --recurse-submodules ==="
git pull --recurse-submodules
echo ""

# === Step 2: Build image ===
echo "=== Step 2: docker build ==="
docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
echo ""

# === Step 3: Build workspace ===
echo "=== Step 3: docker build workspace ==="
docker run --rm -v $(pwd):/home/benchmark/ros_ws fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
echo ""

# === Step 4: Run tests for each method ===
METHODS="soft fpfh icp geotransformer regtr hybridpoint pointreggpt"

for METHOD in $METHODS; do
  echo "=============================================="
  echo "  Testing: $METHOD"
  echo "=============================================="
  docker run --rm \
    -v $(pwd):/home/benchmark/ros_ws \
    -v $(pwd)/dataFolder:/data:ro \
    -v $(pwd)/weights:/volume/weights:ro \
    -v ./test_results/$METHOD:/volume/results \
    fsbench:latest /usr/local/bin/docker-entrypoint-benchmark.sh $METHOD 2 --test
  echo ""
done

echo "=============================================="
echo "  All tests complete!"
echo "=============================================="
echo "Results in: ./test_results/"
ls -la ./test_results/*/outfile_*.csv 2>/dev/null || echo "(no output CSV files)"
