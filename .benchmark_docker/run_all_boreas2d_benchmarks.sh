#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results"
mkdir -p "$RESULTS_DIR"

# Optional global worker override: pass a number as the first argument to force
# ALL benchmarks to use that many workers (e.g. quick tests or weak machines).
# By default, each per-method script uses its own tuned NUM_WORKERS default.
GLOBAL_WORKERS="${1:-}"
DATA_DIR="/Users/timhansen/Documents/dataFolder/radar_boreas"

# Random azimuth rotation (U[0,360) deg, at bin level, GT-corrected) applied
# to the CURRENT scan of every pair in EVERY benchmark.
RAND_ROT_ENABLED=true
RAND_ROT_SEED=42

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
    script="$SCRIPT_DIR/boreas2d/run_boreas_${benchmark}.sh"
    echo "================================================"
    echo "Running benchmark: $benchmark"
    echo "Script: $script"
    echo "Output: $output_file"
    echo "Workers: ${GLOBAL_WORKERS:-per-method default}"
    echo "Random rot: ${RAND_ROT_ENABLED} (seed $RAND_ROT_SEED)"
    echo "================================================"
    workers_args=()
    [ -n "$GLOBAL_WORKERS" ] && workers_args+=("$GLOBAL_WORKERS")
    rand_args=()
    if [ "$RAND_ROT_ENABLED" = "true" ]; then
        rand_args+=(--apply-rand-rot --rand-rot-seed "$RAND_ROT_SEED")
    fi
    if bash "$script" "${workers_args[@]}" "${rand_args[@]}" --data-dir "$DATA_DIR" > "$output_file" 2>&1; then
        echo "  Exit code: 0" | tee -a "$output_file"
    else
        exit_code=$?
        echo "  Exit code: $exit_code" | tee -a "$output_file"
    fi
    echo ""
done

echo "All benchmarks finished. Results in: $RESULTS_DIR"
