#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# ================================================================
#  SOFT Parameter Benchmark Runner
#  Tests all combinations of SOFT parameters at N=64,
#  noise=None, data_type=val. Outputs param-tagged CSVs for
#  later comparison.
#
#  Runs a single docker container that loops over all combos
#  internally (avoids conda env recreation overhead).
#
#  Usage:
#    bash .benchmark_docker/run_soft_param_bench.sh [num_workers]
#    bash .benchmark_docker/run_soft_param_bench.sh 8 --range 0 89
#    bash .benchmark_docker/run_soft_param_bench.sh --test
# ================================================================

# === Defaults ===
NUM_WORKERS=8
TEST_MODE=""
RANGE_START=0
RANGE_END=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --range) RANGE_START="$2"; RANGE_END="$3"; shift 3 ;;
    --test) TEST_MODE="--test"; shift ;;
    *) NUM_WORKERS="$1"; shift ;;
  esac
done

# === Prerequisites check ===
if ! command -v docker &>/dev/null; then
    echo "ERROR: docker is not installed or not in PATH"
    exit 1
fi

# === Logging ===
RESULTS_DIR="test_results/soft_param_bench"
mkdir -p "$RESULTS_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="test_results/run_param_bench_${TIMESTAMP}.log"
exec > >(tee -a "$LOG_FILE" 2>&1)

echo "=============================================="
echo "  SOFT Parameter Benchmark"
echo "=============================================="
echo "Started: $(date)"
echo "Workers: $NUM_WORKERS"
echo "Results: $RESULTS_DIR"
echo "Log:     $LOG_FILE"
echo ""

# === Config ===
N=64
TOTAL_SAMPLES=1331
if [ -n "$TEST_MODE" ]; then
    TOTAL_SAMPLES=1
    echo "*** TEST MODE: 1 sample per combo ***"
fi

# Parameter arrays
CLAHE_VALUES=(0 1)
NORM_VALUES=(0 1 2)
ROT_VALUES=(0.01 0.001 0.0001)
TRANS_VALUES=(0.1 0.01 0.001)
# Band profiles: profile_name:r_min:r_max
BAND_PROFILES=(
  "low:4:16"
  "default:8:24"
  "wide:4:28"
  "high:16:28"
  "narrow:12:20"
)

# === Build image (once) ===
if ! docker image inspect fsbench:latest >/dev/null 2>&1; then
    echo "=== [1/2] Building docker image ==="
    docker build -f .benchmark_docker/Dockerfile -t fsbench:latest .
    echo ""
else
    echo "=== Docker image fsbench:latest already exists, skipping build ==="
fi

# === Build workspace (once) ===
if [ ! -d "install/soft20" ]; then
    echo "=== [2/2] Building workspace ==="
    docker run --rm -v "$(pwd):/home/benchmark/ros_ws" fsbench:latest /usr/local/bin/docker-entrypoint-build.sh
    echo ""
else
    echo "=== Workspace already built (install/soft20 exists), skipping ==="
fi

# === Generate all combos ===
COMBOS=()
for CLAHE in "${CLAHE_VALUES[@]}"; do
  for NORM in "${NORM_VALUES[@]}"; do
    for ROT in "${ROT_VALUES[@]}"; do
      for TRANS in "${TRANS_VALUES[@]}"; do
        for BAND in "${BAND_PROFILES[@]}"; do
            IFS=':' read -r BNAME RMIN RMAX <<< "$BAND"
            COMBOS+=("${N}:${CLAHE}:${NORM}:${ROT}:${TRANS}:${BNAME}:${RMIN}:${RMAX}")
        done
      done
    done
  done
done

TOTAL_COMBOS=${#COMBOS[@]}

# Determine range to process
if [ -z "$RANGE_END" ]; then
    RANGE_END=$((TOTAL_COMBOS - 1))
fi
if [ "$RANGE_END" -ge "$TOTAL_COMBOS" ]; then
    RANGE_END=$((TOTAL_COMBOS - 1))
fi
NUM_TO_RUN=$((RANGE_END - RANGE_START + 1))

echo ""
echo "=============================================="
echo "  Parameter Grid: ${TOTAL_COMBOS} total combos"
echo "  Running: combos [${RANGE_START}..${RANGE_END}] = ${NUM_TO_RUN} combos"
echo "=============================================="
echo "N: ${N}, CLAHE: ${CLAHE_VALUES[*]}"
echo "Normalization: ${NORM_VALUES[*]}"
echo "Level Rotation: ${ROT_VALUES[*]}"
echo "Level Translation: ${TRANS_VALUES[*]}"
echo "Band profiles: low(4/16) default(8/24) wide(4/28) high(16/28) narrow(12/20)"
echo ""

# Extract the subset
COMBO_SUBSET=("${COMBOS[@]:RANGE_START:NUM_TO_RUN}")

# === Run single docker container that loops over all combos ===
echo "=== Starting docker container ==="
echo ""

docker run --rm \
  -e NUM_WORKERS="$NUM_WORKERS" \
  -e TOTAL_SAMPLES="$TOTAL_SAMPLES" \
  -e N="$N" \
  -v "$(pwd):/home/benchmark/ros_ws" \
  -v "$(pwd)/dataFolder:/data:ro" \
  -v "$(pwd)/weights:/volume/weights:ro" \
  -v "$(pwd)/test_results:/volume/results" \
  --entrypoint /bin/bash \
  fsbench:latest \
  -c '
set -euo pipefail

. /opt/ros/jazzy/setup.bash
. /home/benchmark/ros_ws/install/setup.bash
source /opt/miniforge3/etc/profile.d/conda.sh
if ! conda env list | grep -q "^ml "; then
    echo "Creating conda env ml..."
    conda env create -f /home/benchmark/ros_ws/.devcontainer/environment.yml
fi
conda activate ml
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
export PYTHONPATH=/home/benchmark/ros_ws/install/fsregistration/lib/fsregistration:$PYTHONPATH

cd /home/benchmark/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D

(cd predator/cpp_wrappers && bash compile_wrappers.sh >/dev/null 2>&1)

RESULTS_DIR="/volume/results/soft_param_bench"
mkdir -p "$RESULTS_DIR"

NUM_WORKERS=${NUM_WORKERS:-8}
TOTAL_SAMPLES=${TOTAL_SAMPLES:-1331}
N=${N:-64}

float_to_tag() {
    local v="$1"
    if [ "$v" = "0.01" ]; then echo "1e-2"
    elif [ "$v" = "0.001" ]; then echo "1e-3"
    elif [ "$v" = "0.0001" ]; then echo "1e-4"
    elif [ "$v" = "0.1" ]; then echo "1e-1"
    else echo "$v"
    fi
}

TOTAL_COMBOS=$#
COUNT=0
FAIL_COUNT=0

for COMBO in "$@"; do
    COUNT=$((COUNT + 1))
    IFS=":" read -r N_VAL CLAHE_VAL NORM_VAL ROT_VAL TRANS_VAL BNAME RMIN_VAL RMAX_VAL <<< "$COMBO"

    ROT_TAG=$(float_to_tag "$ROT_VAL")
    TRANS_TAG=$(float_to_tag "$TRANS_VAL")
    TAG="N${N_VAL}_clahe${CLAHE_VAL}_r${RMIN_VAL}-${RMAX_VAL}_rot${ROT_TAG}_trans${TRANS_TAG}_norm${NORM_VAL}"
    OUTFILE="${RESULTS_DIR}/outfile_soft_${TAG}_None_val.csv"

    if [ -f "$OUTFILE" ]; then
        echo "[$COUNT/$TOTAL_COMBOS] SKIP: $TAG"
        continue
    fi

    echo ""
    echo "=============================================="
    echo "  [$COUNT/$TOTAL_COMBOS] $TAG"
    echo "=============================================="

    if python3 bashScripts/run_parallel_batches.py \
        --config configFiles/predatorNothingBenchmark.yaml \
        --noise-level None \
        --data-type val \
        --total-samples "$TOTAL_SAMPLES" \
        --batch-size 100 \
        --num-workers "$NUM_WORKERS" \
        --model-type soft \
        --soft-N "$N_VAL" \
        --soft-use-clahe "$CLAHE_VAL" \
        --soft-r-min "$RMIN_VAL" \
        --soft-r-max "$RMAX_VAL" \
        --soft-level-rotation "$ROT_VAL" \
        --soft-level-translation "$TRANS_VAL" \
        --soft-normalization "$NORM_VAL"
    then
        echo "  run_parallel_batches.py OK"
    else
        echo "  ERROR: run_parallel_batches.py failed for $TAG"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    if ! python3 bashScripts/merge_and_deduplicate.py \
        --noise-level None \
        --data-type val \
        --model-type soft \
        --soft-N "$N_VAL"
    then
        echo "  ERROR: merge_and_deduplicate.py failed for $TAG"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi

    SRC="outputFiles/soft/outfile_soft_N${N_VAL}_None_val.csv"
    if [ -f "$SRC" ]; then
        mv "$SRC" "$OUTFILE"
        echo "  -> Saved: $(basename "$OUTFILE")"
    else
        echo "  ERROR: Output CSV not found at $SRC"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    rm -f outputFiles/soft/batch_soft_None_val_*.csv
    echo "  OK"
done

echo ""
echo "=============================================="
echo "  Container finished"
echo "=============================================="
echo "Processed: $((COUNT - FAIL_COUNT)) combos"
echo "Failed:    $FAIL_COUNT"
echo "Results in: $RESULTS_DIR/"
ls -1 "$RESULTS_DIR"/*.csv 2>/dev/null | wc -l | xargs echo "  CSV files:"
echo ""
' bash "${COMBO_SUBSET[@]}"

# === Summary ===
echo ""
echo "=============================================="
echo "  Benchmark Complete"
echo "=============================================="
echo "Results in: ${RESULTS_DIR}/"
ls -1 "${RESULTS_DIR}"/*.csv 2>/dev/null | wc -l | xargs echo "Total CSV files:"
echo ""
echo "=============================================="
