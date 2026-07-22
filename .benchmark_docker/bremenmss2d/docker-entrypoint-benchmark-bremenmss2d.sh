#!/usr/bin/env bash
set -eo pipefail

# ============================================================================
# Docker entry point for Bremen-MSS 2D benchmarks
#
# Usage (from outside Docker):
#   docker run --rm \
#     -v /path/to/ros_ws:/home/benchmark/ros_ws \
#     -v /path/to/Bremen-MSS-Processed:/data:ro \
#     -v /path/to/results:/volume/results \
#     fsbench:latest \
#     bash /home/benchmark/ros_ws/.benchmark_docker/bremenmss2d/docker-entrypoint-benchmark-bremenmss2d.sh \
#       --method fs2d --sequences all --N 256 --num-workers 4
#
# Or via the convenience runner:
#   bash .benchmark_docker/bremenmss2d/run_bremenmss_fs2d.sh
# ============================================================================

# === Verify build artifacts exist ===
if [ ! -d /home/benchmark/ros_ws/install/soft20 ]; then
  echo "ERROR: soft20 not built. Run 'docker-entrypoint-build.sh' first."
  exit 1
fi

# === 1. Source ROS2 + workspace ===
. /opt/ros/jazzy/setup.bash
. /home/benchmark/ros_ws/install/setup.bash

# === 2. Create and activate conda env ===
source /opt/miniforge3/etc/profile.d/conda.sh
ENV_NAME=ml
ENV_FILE=/home/benchmark/ros_ws/.devcontainer/environment.yml

if conda env list | grep -q "^${ENV_NAME} "; then
  echo ">>> Conda env $ENV_NAME exists, activating..."
else
  echo ">>> Creating conda env $ENV_NAME..."
  conda env create -f "$ENV_FILE"
fi

conda activate "$ENV_NAME"

# Install missing packages at runtime (no rebuild needed)
python -c "import imreg_dft" 2>/dev/null || pip install --no-deps imreg-dft

# === 3. Set library paths ===
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
# pybind_registration_2d lives in the fsregistration install
export PYTHONPATH="/home/benchmark/ros_ws/install/fsregistration/lib/fsregistration:$PYTHONPATH"

echo ">>> LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
echo ">>> PYTHONPATH=$PYTHONPATH"

# === 4. Cd to radar dataset directory ===
cd /home/benchmark/ros_ws/src/fsregistration/pythonScripts/radarDataset

# === 5. Parse arguments ===
# Extra args after docker-entrypoint name are passed to bremenMssBenchmarkParallel.py
METHOD="fs2d"
SEQUENCES="all"
N=256
RADIUS=22.5
NUM_WORKERS=4
OUTPUT_DIR="/volume/results"
METHOD_CONFIG=""
SAVE_BLENDED=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --method) METHOD="$2"; shift 2 ;;
    --sequences) SEQUENCES="$2"; shift 2 ;;
    --N) N="$2"; shift 2 ;;
    --radius) RADIUS="$2"; shift 2 ;;
    --num-workers) NUM_WORKERS="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --method-config) METHOD_CONFIG="$2"; shift 2 ;;
    --save-blended) SAVE_BLENDED="--save-blended"; shift ;;
    --test) MAX_FRAMES="5"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

echo ""
echo "=============================================="
echo "  Bremen-MSS 2D Benchmark (Docker)"
echo "=============================================="
echo "Method:       $METHOD"
echo "Sequences:    $SEQUENCES"
echo "N:            $N"
echo "Radius:       $RADIUS"
echo "Workers:      $NUM_WORKERS"
echo "Output dir:   $OUTPUT_DIR"
echo "Data dir:     /data"
echo "=============================================="
echo ""

# === 6. Run benchmark ===
python3 bremenMssBenchmarkParallel.py \
  --method "$METHOD" \
  --sequences "$SEQUENCES" \
  --N "$N" \
  --radius "$RADIUS" \
  --num-workers "$NUM_WORKERS" \
  --output-dir "$OUTPUT_DIR" \
  ${METHOD_CONFIG:+--method-config "$METHOD_CONFIG"} \
  ${SAVE_BLENDED:+--save-blended} \
  /data

EXIT_CODE=$?
echo ""
echo "=============================================="
echo "  Benchmark exit code: $EXIT_CODE"
echo "=============================================="
exit $EXIT_CODE
