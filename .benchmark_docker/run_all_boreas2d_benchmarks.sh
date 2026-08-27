#!/bin/bash
set -euo pipefail

# ============================================================================
# Run all Boreas 2D benchmarks (FS2D, SIFT, KAZE, AKAZE, Fourier-Mellin, ICP,
# NDT_p2d, LoFTR, EfficientLoFTR, LightGlue) sequentially.
#
# Usage:
#   bash run_all_boreas2d_benchmarks.sh <outputdir> [options]
#
# <outputdir>  Folder name where ALL results are stored, under benchmark_results/:
#                benchmark_results/<outputdir>/
#              It holds the per-method output logs AND the benchmark result
#              CSVs. Give each dataset/run its own name so concurrent runs on
#              different machines/datasets don't overwrite each other.
#
# Options:
#   --workers N          Force ALL benchmarks to use N workers
#                        (default: each method's own tuned default).
#   --rand-rot on|off    Random azimuth rotation (U[0,360) deg, at bin level,
#                        GT-corrected) applied to the CURRENT scan of every
#                        pair in EVERY benchmark. Default: off.
#   --rand-rot-seed N    RNG seed for the random rotation. Default: 42.
#   --rand-rot-min N     Minimum rotation magnitude in degrees (>= 0).
#                        Default: 0.0. Only used with --rand-rot on.
#   --rand-rot-max N     Maximum rotation magnitude in degrees. The rotation
#                        direction (sign) is random, so values span both
#                        directions, e.g. --rand-rot-min 30 --rand-rot-max 60
#                        yields rotations in [-60,-30] U [+30,+60] deg.
#                        Default: 180.0. Only used with --rand-rot on.
#   --matching-step N    Override the matching step (register every Nth frame,
#                        pairs formed from frame 0) for ALL benchmarks.
#                        Default: each method's own default.
#   --data-dir PATH      Path to the Boreas radar dataset folder.
#                        Default: /Users/timhansen/Documents/dataFolder/radar_boreas
#
# Examples:
#   bash run_all_boreas2d_benchmarks.sh boreas_norot
#   bash run_all_boreas2d_benchmarks.sh boreas_rot_8w --rand-rot on --workers 8
#   bash run_all_boreas2d_benchmarks.sh band_30_60 --rand-rot on \
#       --rand-rot-min 30 --rand-rot-max 60 \
#       --data-dir /home/tim-external/dataFolder/radar_boreas
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: run_all_boreas2d_benchmarks.sh <outputdir> [options]

<outputdir>  Folder name (under benchmark_results/) where ALL results are
             stored: benchmark_results/<outputdir>/

Options:
  --workers N          Force all benchmarks to use N workers (default: per-method)
  --rand-rot on|off    Random azimuth rotation (U[0,360) deg, bin-level, GT-corrected).
                       Default: off
  --rand-rot-seed N    RNG seed for the random rotation. Default: 42
  --rand-rot-min N     Min rotation magnitude in degrees (>= 0). Default: 0.0
  --rand-rot-max N     Max rotation magnitude in degrees; direction (sign) is
                       random, e.g. 30/60 => [-60,-30] U [30,60] deg. Default: 180.0
  --matching-step N    Override matching step (register every Nth frame) for
                       all benchmarks (default: per-method)
  --data-dir PATH      Boreas radar dataset folder
                       (default: /Users/timhansen/Documents/dataFolder/radar_boreas)
EOF
}

if [ $# -lt 1 ]; then
    usage
    exit 1
fi

RAW_OUTPUTDIR="$1"
if [ "$RAW_OUTPUTDIR" = "-h" ] || [ "$RAW_OUTPUTDIR" = "--help" ]; then
    usage
    exit 0
fi
shift

DATA_DIR="/Users/timhansen/Documents/dataFolder/radar_boreas"
GLOBAL_WORKERS=""
RAND_ROT_ENABLED=false
RAND_ROT_SEED=42
RAND_ROT_MIN=0.0
RAND_ROT_MAX=180.0
MATCHING_STEP=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --workers) GLOBAL_WORKERS="$2"; shift 2 ;;
        --rand-rot) RAND_ROT_ENABLED="$2"; shift 2 ;;
        --rand-rot-seed) RAND_ROT_SEED="$2"; shift 2 ;;
        --rand-rot-min) RAND_ROT_MIN="$2"; shift 2 ;;
        --rand-rot-max) RAND_ROT_MAX="$2"; shift 2 ;;
        --matching-step) MATCHING_STEP="$2"; shift 2 ;;
        --data-dir) DATA_DIR="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "Unknown argument: $1"; usage; exit 1 ;;
    esac
done

# Normalize --rand-rot value
case "$RAND_ROT_ENABLED" in
    on|true|1) RAND_ROT_ENABLED=true ;;
    off|false|0) RAND_ROT_ENABLED=false ;;
    *) echo "ERROR: --rand-rot must be 'on' or 'off' (got '$RAND_ROT_ENABLED')"; exit 1 ;;
esac

# Sanitize outputdir to a simple folder name
OUTPUTDIR="$(basename -- "$RAW_OUTPUTDIR")"
if [ -z "$OUTPUTDIR" ] || [ "$OUTPUTDIR" = "." ] || [ "$OUTPUTDIR" = "/" ]; then
    echo "ERROR: invalid <outputdir>: '$RAW_OUTPUTDIR'"
    exit 1
fi

# All results (wrapper logs + benchmark CSVs) go under benchmark_results/<outputdir>.
RESULTS_DIR="$ROOT_DIR/benchmark_results/$OUTPUTDIR"
mkdir -p "$RESULTS_DIR"

# Redirect every per-method script's output into the same folder. Keep this
# relative to the repo root so the per-method scripts' docker mount
# "$(pwd)/$RESULTS_DIR:/volume/results" resolves correctly.
export RESULTS_DIR_OVERRIDE="benchmark_results/$OUTPUTDIR"

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
    echo "Random rot: ${RAND_ROT_ENABLED} (seed $RAND_ROT_SEED, band ${RAND_ROT_MIN}..${RAND_ROT_MAX} deg)"
    echo "Matching step: ${MATCHING_STEP:-per-method default}"
    echo "Output dir: $RESULTS_DIR"
    echo "================================================"
    workers_args=()
    [ -n "$GLOBAL_WORKERS" ] && workers_args+=("$GLOBAL_WORKERS")
    rand_args=()
    if [ "$RAND_ROT_ENABLED" = "true" ]; then
        rand_args+=(--apply-rand-rot --rand-rot-seed "$RAND_ROT_SEED")
        rand_args+=(--rand-rot-min "$RAND_ROT_MIN" --rand-rot-max "$RAND_ROT_MAX")
    fi
    step_args=()
    [ -n "$MATCHING_STEP" ] && step_args+=(--matching_step "$MATCHING_STEP")
    if bash "$script" "${workers_args[@]}" "${rand_args[@]}" "${step_args[@]}" --data-dir "$DATA_DIR" > "$output_file" 2>&1; then
        echo "  Exit code: 0" | tee -a "$output_file"
    else
        exit_code=$?
        echo "  Exit code: $exit_code" | tee -a "$output_file"
    fi
    echo ""
done

echo "All benchmarks finished. Results in: $RESULTS_DIR"
