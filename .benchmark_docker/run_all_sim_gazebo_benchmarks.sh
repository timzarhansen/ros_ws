#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"
chmod 777 "$RESULTS_DIR"

# ============================================================================
# Configuration (edit here)
# ============================================================================

# Methods to benchmark (must match run_sim_gazebo_<method>.sh scripts)
BENCHMARKS=(
    "fs2d"
    "sift"
    "kaze"
    "akaze"
    "fourier_mellin"
    "icp"
    "ndt_p2d"
    "loftr"
    "eloftr"
    "lightglue"
)

# Noise models applied to the points BEFORE image/pointcloud generation
# (same scheme as the 3D profiling benchmark)
NOISE_LEVELS=(
    "None"
    "low"
    "high"
    "low_gauss"
    "high_gauss"
    "low_salt_pepper"
    "high_salt_pepper"
)

# Image grid size and scene radius for all methods.
#   N=256, radius=30.0 -> pixel size 0.234 m (full 30 m coverage)
#   N=256, radius=15.0 -> pixel size 0.117 m (clips returns beyond 15 m)
DEFAULT_N=256
DEFAULT_RADIUS=30.0

# ============================================================================

NUM_WORKERS=1
TEST_MODE=""
DATA_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --test) TEST_MODE="--test"; shift ;;
    --data-dir) DATA_DIR="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

if [ -z "$DATA_DIR" ]; then
  echo "ERROR: --data-dir is required (dataset dir or parent of dataset dirs)"
  exit 1
fi

for benchmark in "${BENCHMARKS[@]}"; do
    for noise in "${NOISE_LEVELS[@]}"; do
        output_file="$RESULTS_DIR/${benchmark}_${noise}_output.txt"
        script="$SCRIPT_DIR/simulation_gazebo_scans/run_sim_gazebo_${benchmark}.sh"
        echo "================================================"
        echo "Running benchmark: $benchmark (noise: $noise)"
        echo "Script: $script"
        echo "Output: $output_file"
        echo "================================================"
        if bash "$script" "$NUM_WORKERS" ${TEST_MODE:+"$TEST_MODE"} \
             --data-dir "$DATA_DIR" --noise-level "$noise" \
             --N "$DEFAULT_N" --radius "$DEFAULT_RADIUS" > "$output_file" 2>&1; then
            echo "  Exit code: 0" | tee -a "$output_file"
        else
            exit_code=$?
            echo "  Exit code: $exit_code" | tee -a "$output_file"
        fi
        echo ""
    done
done

echo "All benchmarks finished. Results in: $RESULTS_DIR"
