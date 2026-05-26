#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "=============================================="
echo "  Cleanup Before Benchmark"
echo "=============================================="

# Clean matchingProfiling3D outputFiles
echo ">>> Cleaning matchingProfiling3D/outputFiles..."
rm -rf src/fsregistration/pythonScripts/matchingProfiling3D/outputFiles/*
mkdir -p src/fsregistration/pythonScripts/matchingProfiling3D/outputFiles

# Clean test_results
echo ">>> Cleaning .benchmark_docker/test_results..."
rm -rf .benchmark_docker/test_results/*
mkdir -p .benchmark_docker/test_results

echo ">>> Cleanup complete."
