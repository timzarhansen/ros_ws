#!/bin/bash
set -euo pipefail

# ============================================================================
# Run Boreas 2D benchmarks (FS2D, SIFT, KAZE, AKAZE, Fourier-Mellin, ICP,
# NDT_p2d, LoFTR, EfficientLoFTR, LightGlue, SURF) sequentially.
#
# Usage:
#   bash run_all_boreas2d_benchmarks.sh [<outputdir>] [options]
#
# With NO arguments, defaults are used:
#   - ALL methods are run
#   - no random rotation is applied
#   - results go to benchmark_results/ (the default output)
#
# <outputdir>  Folder where ALL results are stored, under benchmark_results/:
#              benchmark_results/<outputdir>/
#              You may also pass the full path, e.g. benchmark_results/test1/
#              (the benchmark_results/ prefix is stripped, no double nesting).
#              Default: benchmark_results/ (results land directly in it).
#              Alias flag: --outputdir <path>
#
# Options (shared, applied to every method in the run):
#   --method M[,M...]  Methods to run: fs2d, sift, kaze, akaze,
#                      fourier_mellin, icp, ndt_p2d, loftr, eloftr,
#                      lightglue, surf (comma-separated list or 'all').
#                      Default: all
#   --workers N        Force ALL benchmarks to use N workers
#                      (default: each method's own tuned default).
#   --rand-rot on|off  Random azimuth rotation (U[0,360) deg, at bin level,
#                      GT-corrected) applied to the CURRENT scan of every
#                      pair in EVERY benchmark. Default: off.
#   --rand-rot-seed N  RNG seed for the random rotation. Default: 42.
#   --rand-rot-min N   Minimum rotation magnitude in degrees (>= 0).
#                      Default: 0.0. Only used with --rand-rot on.
#   --rand-rot-max N   Maximum rotation magnitude in degrees; direction
#                      (sign) is random, so e.g. 30/60 yields [-60,-30]
#                      U [+30,+60] deg. Default: 180.0.
#   --matching-step N  Override matching step (register every Nth frame,
#                      pairs formed from frame 0).
#   --sequences SPEC   Sequence selection: all, 0-15, 0,1,2. Default: all.
#   --N N              Image grid size (N x N).
#   --radius M         Scene radius in meters.
#   --start-frame N    First frame index. Default: 0.
#   --max-frames N     Cap sequence length (default: full).
#   --save-blended     Save blended images for each pair.
#   --test             Quick test: N=64, matching_step=1, max_frames=10.
#   --rebuild          Force a rebuild of the docker image fsbench:latest.
#                      Without it, an existing image is reused as-is.
#   --data-dir PATH    Path to the Boreas radar dataset folder.
#                      Default: /Users/timhansen/Documents/dataFolder/radar_boreas
#
# Method-specific options (only forwarded to the matching method):
#   Prefix form: --<method>-<flag> <value>, e.g.
#     --sift-contrast-threshold 8, --icp-voxel-size 1.0,
#     --loftr-ransac-threshold 0.9, --kaze-threshold 0.001, ...
#   FS2D options are bare: --r-min, --r-max, --normalization, --use-direct,
#     --use-clahe, --use-hamming, --multiple-radii, --use-gauss,
#     --use-weighted-peak-score, --use-phase-correlation,
#     --potential_for_necessary_peak, --level_potential_rotation,
#     --method-config "<fs2d.key=value ...>"
#   ICP/NDT: --use-raw-pointcloud, --raw-intensity-threshold <v>
#
# Examples:
#   bash run_all_boreas2d_benchmarks.sh
#   bash run_all_boreas2d_benchmarks.sh benchmark_results/test1/
#   bash run_all_boreas2d_benchmarks.sh --method fs2d,sift --sequences 0-5
#   bash run_all_boreas2d_benchmarks.sh --rebuild --rand-rot on --workers 8
#   bash run_all_boreas2d_benchmarks.sh --method sift --sift-contrast-threshold 8
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

usage() {
    cat <<'EOF'
Usage: run_all_boreas2d_benchmarks.sh [<outputdir>] [options]

<outputdir>  Folder where ALL results are stored, under benchmark_results/:
             benchmark_results/<outputdir>/ (default: benchmark_results/).
             'benchmark_results/<name>/' and '--outputdir <path>' also work.

Options:
  --method M[,M...]    Methods to run (default: all). Available: fs2d, sift,
                       kaze, akaze, fourier_mellin, icp, ndt_p2d, loftr,
                       eloftr, lightglue, surf
  --workers N          Force all benchmarks to use N workers (default: per-method)
  --rand-rot on|off    Random azimuth rotation (U[0,360) deg, bin-level, GT-corrected).
                       Default: off
  --rand-rot-seed N    RNG seed for the random rotation. Default: 42
  --rand-rot-min N     Min rotation magnitude in degrees (>= 0). Default: 0.0
  --rand-rot-max N     Max rotation magnitude; sign is random, e.g. 30/60 =>
                       [-60,-30] U [30,60] deg. Default: 180.0
  --matching-step N    Override matching step for all benchmarks (default: per-method)
  --sequences SPEC     Sequence selection: all, 0-15, 0,1,2. Default: all
  --N N                Image grid size (N x N) for all benchmarks
  --radius M           Scene radius in meters for all benchmarks
  --start-frame N      First frame index for all benchmarks. Default: 0
  --max-frames N       Cap sequence length for all benchmarks (default: full)
  --save-blended       Save blended images for each pair
  --test               Quick test: N=64, matching_step=1, max_frames=10
  --rebuild            Force rebuild of docker image fsbench:latest
  --dry-run            Print the exact per-method commands that would run,
                       then exit (does NOT touch docker)
  --data-dir PATH      Boreas radar dataset folder
                       (default: /Users/timhansen/Documents/dataFolder/radar_boreas)

Method-specific options (only forwarded to their method):
  --<method>-<flag> <value>    e.g. --sift-contrast-threshold 8,
                               --icp-voxel-size 1.0, --loftr-ransac-threshold 0.9,
                               --kaze-threshold 0.001
  --dry-run            Print per-method commands without running anything
  FS2D (bare): --r-min, --r-max, --normalization, --use-direct, --use-clahe,
               --use-hamming, --multiple-radii, --use-gauss,
               --use-weighted-peak-score, --use-phase-correlation,
               --potential_for_necessary_peak, --level_potential_rotation,
               --method-config "<fs2d.key=value ...>"
  ICP/NDT:     --use-raw-pointcloud, --raw-intensity-threshold <v>
EOF
}

# ============================================================================
# Defaults
# ============================================================================
DATA_DIR="/Users/timhansen/Documents/dataFolder/radar_boreas"
GLOBAL_WORKERS=""
RAND_ROT_ENABLED=false
RAND_ROT_SEED=42
RAND_ROT_MIN=0.0
RAND_ROT_MAX=180.0
MATCHING_STEP=""
SEQUENCES=""
N=""
RADIUS=""
START_FRAME=""
MAX_FRAMES=""
SAVE_BLENDED=false
TEST_MODE=false
REBUILD=false
DRY_RUN=false
METHOD_SPEC="all"
OUTPUT_PATH=""
OUTDIR_FLAG_SEEN=false
EXTRA_ARGS=()

BENCHMARKS=(fs2d sift kaze akaze fourier_mellin icp ndt_p2d loftr eloftr lightglue)

# ============================================================================
# Arg parsing
# ============================================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --method) METHOD_SPEC="$2"; shift 2 ;;
        --workers) GLOBAL_WORKERS="$2"; shift 2 ;;
        --rand-rot) RAND_ROT_ENABLED="$2"; shift 2 ;;
        --rand-rot-seed) RAND_ROT_SEED="$2"; shift 2 ;;
        --rand-rot-min) RAND_ROT_MIN="$2"; shift 2 ;;
        --rand-rot-max) RAND_ROT_MAX="$2"; shift 2 ;;
        --matching-step|--matching_step) MATCHING_STEP="$2"; shift 2 ;;
        --sequences) SEQUENCES="$2"; shift 2 ;;
        --N) N="$2"; shift 2 ;;
        --radius) RADIUS="$2"; shift 2 ;;
        --start-frame|--start_frame) START_FRAME="$2"; shift 2 ;;
        --max-frames|--max_frames) MAX_FRAMES="$2"; shift 2 ;;
        --save-blended) SAVE_BLENDED=true; shift ;;
        --test) TEST_MODE=true; shift ;;
        --rebuild) REBUILD=true; shift ;;
        --dry-run) DRY_RUN=true; shift ;;
        --data-dir) DATA_DIR="$2"; shift 2 ;;
        --outputdir) OUTDIR_FLAG_SEEN=true; OUTPUT_PATH="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        # --- FS2D-specific options (bare) -------------------------------
        --r-min|--r-max|--normalization|--use-direct|--use-clahe|--use-hamming|\
        --multiple-radii|--use-gauss|--use-weighted-peak-score|\
        --use-phase-correlation|--potential_for_necessary_peak|\
        --level_potential_rotation|--method-config|--raw-intensity-threshold)
            EXTRA_ARGS+=("$1" "${2:-}"); shift 2 ;;
        --use-raw-pointcloud)
            EXTRA_ARGS+=(--use-raw-pointcloud); shift ;;
        # --- Method-prefixed options (--<method>-<flag> <value>) --------
        *)
            case "$1" in
                --sift-*|--kaze-*|--akaze-*|--icp-*|--ndt-*|--loftr-*|\
                --eloftr-*|--lightglue-*|--fm-*|--surf-*)
                    EXTRA_ARGS+=("$1" "${2:-}"); shift 2 ;;
                *)
                    # Optional positional: <outputdir> (only if no flag seen yet)
                    if [ "$OUTDIR_FLAG_SEEN" = false ] && [ -z "$OUTPUT_PATH" ]; then
                        OUTPUT_PATH="$1"; shift
                    else
                        echo "ERROR: Unknown option: $1"
                        usage
                        exit 1
                    fi
                    ;;
            esac
            ;;
    esac
done

# Normalize --rand-rot value
case "$RAND_ROT_ENABLED" in
    on|true|1) RAND_ROT_ENABLED=true ;;
    off|false|0) RAND_ROT_ENABLED=false ;;
    *) echo "ERROR: --rand-rot must be 'on' or 'off' (got '$RAND_ROT_ENABLED')"; exit 1 ;;
esac

# ============================================================================
# Validate data dir (default is the Mac path)
# ============================================================================
if [ ! -d "$DATA_DIR" ]; then
    echo "ERROR: Boreas data dir not found: $DATA_DIR"
    echo "       Pass --data-dir <path> to point at the dataset (default is the Mac path)."
    exit 1
fi

# ============================================================================
# Method selection
# ============================================================================
SELECTED=()
if [ "$METHOD_SPEC" = "all" ]; then
    SELECTED=("${BENCHMARKS[@]}")
else
    IFS=',' read -ra parts <<< "$METHOD_SPEC"
    for m in "${parts[@]}"; do
        found=false
        for b in "${BENCHMARKS[@]}"; do
            [ "$m" = "$b" ] && found=true
        done
        if [ "$found" = false ]; then
            echo "ERROR: unknown method '$m'. Available: ${BENCHMARKS[*]}"
            exit 1
        fi
        already=false
        for s in "${SELECTED[@]}"; do [ "$s" = "$m" ] && already=true; done
        if [ "$already" = false ]; then
            SELECTED+=("$m")
        fi
    done
    if [ ${#SELECTED[@]} -eq 0 ]; then
        echo "ERROR: no methods selected"
        exit 1
    fi
fi

is_selected() {
    local m
    for m in "${SELECTED[@]}"; do
        [ "$m" = "$1" ] && return 0
    done
    return 1
}

# ============================================================================
# Output folder: benchmark_results/, or benchmark_results/<name>/
# (a passed 'benchmark_results/...' prefix is stripped; no double nesting)
# ============================================================================
OUTPUTDIR=""
RAW_OUTPUTDIR="${OUTPUT_PATH%/}"
case "$RAW_OUTPUTDIR" in
    benchmark_results) RAW_OUTPUTDIR="" ;;
    benchmark_results/*) RAW_OUTPUTDIR="${RAW_OUTPUTDIR#benchmark_results/}" ;;
esac
if [ -n "$RAW_OUTPUTDIR" ]; then
    OUTPUTDIR="$(basename -- "$RAW_OUTPUTDIR")"
    if [ -z "$OUTPUTDIR" ] || [ "$OUTPUTDIR" = "." ] || [ "$OUTPUTDIR" = "/" ]; then
        echo "ERROR: invalid output dir: '$OUTPUT_PATH'"
        exit 1
    fi
fi
RESULTS_DIR="$ROOT_DIR/benchmark_results${OUTPUTDIR:+/$OUTPUTDIR}"
mkdir -p "$RESULTS_DIR"
chmod 777 "$RESULTS_DIR"
# Relative to the repo root so the per-method scripts' docker mount
# "$(pwd)/$RESULTS_DIR:/volume/results" resolves correctly.
export RESULTS_DIR_OVERRIDE="benchmark_results${OUTPUTDIR:+/$OUTPUTDIR}"

# ============================================================================
# Warn about method-specific options whose method is NOT in the run list
# ============================================================================
warn_unselected_extra() {
    local i flag owners owner any
    i=0
    while [ $i -lt ${#EXTRA_ARGS[@]} ]; do
        flag="${EXTRA_ARGS[$i]}"
        case "$flag" in
            --use-raw-pointcloud) i=$((i + 1)) ;;
            *) i=$((i + 2)) ;;
        esac
        case "$flag" in
            --sift-*) owners="sift" ;;
            --kaze-*) owners="kaze" ;;
            --akaze-*) owners="akaze" ;;
            --icp-*) owners="icp" ;;
            --ndt-*) owners="ndt_p2d" ;;
            --loftr-*) owners="loftr" ;;
            --eloftr-*) owners="eloftr" ;;
            --lightglue-*) owners="lightglue" ;;
            --fm-*) owners="fourier_mellin" ;;
            --surf-*) owners="surf" ;;
            --use-raw-pointcloud|--raw-intensity-threshold) owners="icp ndt_p2d" ;;
            --method-config|--r-min|--r-max|--normalization|--use-direct|\
            --use-clahe|--use-hamming|--multiple-radii|--use-gauss|\
            --use-weighted-peak-score|--use-phase-correlation|\
            --potential_for_necessary_peak|--level_potential_rotation) owners="fs2d" ;;
            *) owners="" ;;
        esac
        [ -z "$owners" ] && continue
        any=false
        for owner in $owners; do
            is_selected "$owner" && any=true
        done
        if [ "$any" = false ]; then
            echo "WARNING: '$flag' ignored — belongs to [$(echo "$owners" | tr ' ' ',')], not in the run list" >&2
        fi
    done
}
warn_unselected_extra

# ============================================================================
# Print run configuration
# ============================================================================
echo "=============================================="
echo "  Boreas 2D Benchmark — run_all"
echo "=============================================="
echo "Methods:      ${SELECTED[*]}"
echo "Sequences:    ${SEQUENCES:-all}"
echo "N:            ${N:-per-method default}"
echo "Radius:       ${RADIUS:-per-method default}"
echo "Match step:   ${MATCHING_STEP:-per-method default}"
echo "Start frame:  ${START_FRAME:-0}"
echo "Max frames:   ${MAX_FRAMES:-unlimited}"
echo "Workers:      ${GLOBAL_WORKERS:-per-method default}"
echo "Random rot:   $RAND_ROT_ENABLED (seed $RAND_ROT_SEED, band ${RAND_ROT_MIN}..${RAND_ROT_MAX} deg)"
echo "Save blended: $SAVE_BLENDED"
echo "Test mode:    $TEST_MODE"
echo "Rebuild img:  $REBUILD"
echo "Dry run:      $DRY_RUN (print only, nothing executed)"
echo "Data dir:     $DATA_DIR"
echo "Results dir:  $RESULTS_DIR"
echo "Extra args:   ${EXTRA_ARGS[*]:-none}"
echo ""

# ============================================================================
# Docker image: rebuild only when requested
# ============================================================================
if [ "$REBUILD" = true ]; then
    echo "=== [0/3] Rebuild requested: docker build -f .benchmark_docker/Dockerfile -t fsbench:latest ."
    if [ "$DRY_RUN" = false ]; then
        docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
        echo ""
    fi
else
    echo "=== Docker image: reusing existing fsbench:latest (pass --rebuild to force a rebuild) ==="
fi

# ============================================================================
# Collect method-specific args for one method into EXTRA_FOR
# ============================================================================
EXTRA_FOR=()
collect_extra_for() {
    local m="$1" i flag val
    EXTRA_FOR=()
    i=0
    while [ $i -lt ${#EXTRA_ARGS[@]} ]; do
        flag="${EXTRA_ARGS[$i]}"
        case "$flag" in
            --use-raw-pointcloud) val="" i=$((i + 1)) ;;
            *) val="${EXTRA_ARGS[$((i + 1))]}" i=$((i + 2)) ;;
        esac
        matched=false
        case "$flag" in
            --${m}-*) matched=true ;;
            --use-raw-pointcloud|--raw-intensity-threshold)
                [ "$m" = icp ] || [ "$m" = ndt_p2d ] && matched=true ;;
            --method-config|--r-min|--r-max|--normalization|--use-direct|\
            --use-clahe|--use-hamming|--multiple-radii|--use-gauss|\
            --use-weighted-peak-score|--use-phase-correlation|\
            --potential_for_necessary_peak|--level_potential_rotation)
                [ "$m" = fs2d ] && matched=true ;;
        esac
        if [ "$matched" = true ]; then
            EXTRA_FOR+=("$flag")
            [ -n "$val" ] && EXTRA_FOR+=("$val")
        fi
    done
}

# ============================================================================
# Run selected benchmarks sequentially
# ============================================================================
FAILED_METHODS=()
OK_METHODS=()

for benchmark in "${SELECTED[@]}"; do
    output_file="$RESULTS_DIR/${benchmark}_output.txt"
    script="$SCRIPT_DIR/boreas2d/run_boreas_${benchmark}.sh"
    echo "================================================"
    echo "Running benchmark: $benchmark"
    echo "Script: $script"
    echo "Output: $output_file"
    echo "Workers: ${GLOBAL_WORKERS:-per-method default}"
    echo "Random rot: ${RAND_ROT_ENABLED} (seed $RAND_ROT_SEED, band ${RAND_ROT_MIN}..${RAND_ROT_MAX} deg)"
    echo "Matching step: ${MATCHING_STEP:-per-method default}"
    echo "Results dir: $RESULTS_DIR"
    echo "================================================"

    collect_extra_for "$benchmark"

    args=()
    [ -n "$GLOBAL_WORKERS" ] && args+=("$GLOBAL_WORKERS")
    [ -n "$SEQUENCES" ] && args+=(--sequences "$SEQUENCES")
    [ -n "$N" ] && args+=(--N "$N")
    [ -n "$RADIUS" ] && args+=(--radius "$RADIUS")
    [ -n "$MATCHING_STEP" ] && args+=(--matching_step "$MATCHING_STEP")
    [ -n "$START_FRAME" ] && args+=(--start_frame "$START_FRAME")
    [ -n "$MAX_FRAMES" ] && args+=(--max_frames "$MAX_FRAMES")
    [ "$SAVE_BLENDED" = true ] && args+=(--save-blended)
    [ "$TEST_MODE" = true ] && args+=(--test)
    if [ "$RAND_ROT_ENABLED" = true ]; then
        args+=(--apply-rand-rot --rand-rot-seed "$RAND_ROT_SEED")
        args+=(--rand-rot-min "$RAND_ROT_MIN" --rand-rot-max "$RAND_ROT_MAX")
    fi
    [ ${#EXTRA_FOR[@]} -gt 0 ] && args+=("${EXTRA_FOR[@]}")
    args+=(--data-dir "$DATA_DIR")

    echo "  Args: ${args[*]:-none}"
    if [ "$DRY_RUN" = true ]; then
        echo "  [dry-run] Would run: bash $script ${args[*]:-}"
        OK_METHODS+=("$benchmark")
        echo ""
        continue
    fi
    if bash "$script" "${args[@]}" > "$output_file" 2>&1; then
        echo "  Exit code: 0" | tee -a "$output_file"
        OK_METHODS+=("$benchmark")
    else
        exit_code=$?
        echo "  Exit code: $exit_code" | tee -a "$output_file"
        FAILED_METHODS+=("$benchmark")
    fi
    echo ""
done

# ============================================================================
# Summary
# ============================================================================
echo "=============================================="
echo "  All benchmarks finished — run_all summary"
echo "=============================================="
echo "Results in: $RESULTS_DIR"
echo "OK:     ${OK_METHODS[*]:-none}"
echo "Failed: ${FAILED_METHODS[*]:-none}"
echo "=============================================="

if [ ${#FAILED_METHODS[@]} -gt 0 ]; then
    echo "ERROR: ${#FAILED_METHODS[@]} benchmark(s) failed. See ${RESULTS_DIR}/<method>_output.txt"
    exit 1
fi
exit 0