#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

NUM_WORKERS=1
DATA_DIR="/home/tim-external/dataFolder/Bremen-MSS-Processed"

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

for benchmark in "${BENCHMARKS[@]}"; do
    output_file="$RESULTS_DIR/${benchmark}_output.txt"
    script="$SCRIPT_DIR/bremenmss2d/run_bremenmss_${benchmark}.sh"
    echo "================================================"
    echo "Running benchmark: $benchmark"
    echo "Script: $script"
    echo "Output: $output_file"
    echo "================================================"
    if bash "$script" "$NUM_WORKERS" --data-dir "$DATA_DIR" > "$output_file" 2>&1; then
        echo "  Exit code: 0" | tee -a "$output_file"
    else
        exit_code=$?
        echo "  Exit code: $exit_code" | tee -a "$output_file"
    fi
    echo ""
done

echo "All benchmarks finished. Results in: $RESULTS_DIR"
