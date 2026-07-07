#!/usr/bin/env bash
set -eo pipefail

# ============================================================================
# Docker entry point for Boreas 2D radar benchmarks
#
# Usage (from outside Docker):
#   docker run --rm \
#     -v /path/to/ros_ws:/home/benchmark/ros_ws \
#     -v /path/to/boreas_data:/data:ro \
#     -v /path/to/results:/volume/results \
#     fsbench:latest \
#     bash /home/benchmark/ros_ws/.benchmark_docker/boreas2d/docker-entrypoint-benchmark-boreas2d.sh \
#       --method fs2d --sequences all --N 128 --num-workers 4
#
# Or via the convenience runner:
#   bash .benchmark_docker/boreas2d/run_boreas_fs2d.sh
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

# === 3. Set library paths ===
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
# pybind_registration_2d lives in the fsregistration install
export PYTHONPATH="/home/benchmark/ros_ws/install/fsregistration/lib/fsregistration:$PYTHONPATH"
# Add sdk/radar.py for polar-to-cartesian
export PYTHONPATH="/home/benchmark/ros_ws/src/fsregistration/pythonScripts/radarDataset:$PYTHONPATH"

echo ">>> LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
echo ">>> PYTHONPATH=$PYTHONPATH"

# === 4. Cd to radar dataset directory ===
cd /home/benchmark/ros_ws/src/fsregistration/pythonScripts/radarDataset

# === 5. Parse arguments ===
# Extra args after docker-entrypoint name are passed to boreasBenchmarkParallel.py
# Defaults
METHOD="fs2d"
SEQUENCES="all"
N=128
SIZE_OF_PIXEL=0.5
MATCHING_STEP=5
START_FRAME=0
MAX_FRAMES=""
NUM_WORKERS=4
OUTPUT_DIR="/volume/results"
METHOD_CONFIG=""
SAVE_BLENDED=""

DATA_DIR=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --method) METHOD="$2"; shift 2 ;;
    --sequences) SEQUENCES="$2"; shift 2 ;;
    --N) N="$2"; shift 2 ;;
    --size_of_pixel) SIZE_OF_PIXEL="$2"; shift 2 ;;
    --matching_step) MATCHING_STEP="$2"; shift 2 ;;
    --start_frame) START_FRAME="$2"; shift 2 ;;
    --max_frames) MAX_FRAMES="$2"; shift 2 ;;
    --num-workers) NUM_WORKERS="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --method-config) METHOD_CONFIG="$2"; shift 2 ;;
    --save-blended) SAVE_BLENDED="--save-blended"; shift ;;
    --test) MAX_FRAMES="10"; MATCHING_STEP="1"; N="64"; shift ;;
    *) DATA_DIR="$1"; shift ;;
  esac
done

# Default data dir if not provided
DATA_DIR="${DATA_DIR:-/data}"

echo ""
echo "=============================================="
echo "  Boreas 2D Benchmark (Docker)"
echo "=============================================="
echo "Method:       $METHOD"
echo "Sequences:    $SEQUENCES"
echo "N:            $N"
echo "Size/pixel:   $SIZE_OF_PIXEL"
echo "Match step:   $MATCHING_STEP"
echo "Start frame:  $START_FRAME"
echo "Max frames:   ${MAX_FRAMES:-unlimited}"
echo "Workers:      $NUM_WORKERS"
echo "Output dir:   $OUTPUT_DIR"
echo "Data dir:     $DATA_DIR"
echo "=============================================="
echo ""

# === 6. Run benchmark ===
python3 boreasBenchmarkParallel.py \
  --method "$METHOD" \
  --sequences "$SEQUENCES" \
  --N "$N" \
  --size_of_pixel "$SIZE_OF_PIXEL" \
  --matching_step "$MATCHING_STEP" \
  --start_frame "$START_FRAME" \
  ${MAX_FRAMES:+--max_frames "$MAX_FRAMES"} \
  --num-workers "$NUM_WORKERS" \
  --output-dir "$OUTPUT_DIR" \
  ${METHOD_CONFIG:+--method-config "$METHOD_CONFIG"} \
  ${SAVE_BLENDED:+--save-blended} \
  "$DATA_DIR"

EXIT_CODE=$?
echo ""
echo "=============================================="
echo "  Benchmark exit code: $EXIT_CODE"
echo "=============================================="
exit $EXIT_CODE
