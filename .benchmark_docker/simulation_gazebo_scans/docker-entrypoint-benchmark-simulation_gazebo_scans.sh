#!/usr/bin/env bash
set -eo pipefail

# ============================================================================
# Docker entry point for Lidar Simulation 2D benchmarks
#
# Usage (from outside Docker):
#   docker run --rm \
#     -v /path/to/ros_ws:/home/benchmark/ros_ws \
#     -v /path/to/datasets:/data:ro \
#     -v /path/to/results:/volume/results \
#     fsbench:latest \
#     bash /home/benchmark/ros_ws/.benchmark_docker/simulation_gazebo_scans/\
#         docker-entrypoint-benchmark-simulation_gazebo_scans.sh \
#       --method fs2d --num-workers 4 --N 256 --radius 15 --noise-level None \
#       --output-dir /volume/results \
#       /data
#
# Or via the convenience runner:
#   bash .benchmark_docker/simulation_gazebo_scans/run_sim_gazebo_fs2d.sh
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

# Clone external method repos if missing (standalone git repos, not submodules)
OTHER_DIR="/home/benchmark/ros_ws/src/fsregistration/pythonScripts/radarDataset/otherMethods"

if [ ! -d "$OTHER_DIR/LoFTR/src" ]; then
    echo ">>> Cloning LoFTR..."
    rm -rf "$OTHER_DIR/LoFTR"
    git clone --depth 1 https://github.com/zju3dv/LoFTR.git "$OTHER_DIR/LoFTR"
fi

if [ ! -d "$OTHER_DIR/EfficientLoFTR/src" ]; then
    echo ">>> Cloning EfficientLoFTR..."
    rm -rf "$OTHER_DIR/EfficientLoFTR"
    git clone --depth 1 https://github.com/zju3dv/EfficientLoFTR.git "$OTHER_DIR/EfficientLoFTR"
fi

if [ ! -d "$OTHER_DIR/LightGlue/lightglue" ]; then
    echo ">>> Cloning LightGlue..."
    rm -rf "$OTHER_DIR/LightGlue"
    git clone --depth 1 https://github.com/cvg/LightGlue.git "$OTHER_DIR/LightGlue"
fi

echo ">>> Installing LightGlue package..."
pip install -e "$OTHER_DIR/LightGlue" --quiet

# Patch kornia imports for compatibility with kornia >= 0.6 (drops kornia.utils.grid)
echo ">>> Patching kornia imports in cloned method repos..."
FIX_SCRIPT="/home/benchmark/ros_ws/src/fsregistration/pythonScripts/radarDataset/scripts/fix_kornia_imports.sh"
if [ -f "$FIX_SCRIPT" ]; then
    bash "$FIX_SCRIPT"
else
    echo "WARNING: fix_kornia_imports.sh not found — cloned repos may use incompatible kornia imports"
fi

# === 3. Set library paths ===
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
# pybind_registration_2d lives in the fsregistration install
export PYTHONPATH="/home/benchmark/ros_ws/install/fsregistration/lib/fsregistration:$PYTHONPATH"

echo ">>> LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
echo ">>> PYTHONPATH=$PYTHONPATH"

# === 4. Cd to radar dataset directory ===
cd /home/benchmark/ros_ws/src/fsregistration/pythonScripts/radarDataset

# === 5. Parse arguments ===
METHOD="fs2d"
SEQUENCES="all"
N=256
RADIUS=15.0
NUM_WORKERS=4
OUTPUT_DIR="/volume/results"
METHOD_CONFIG=""
SAVE_BLENDED=""
MAX_FRAMES=""
NOISE_LEVEL="None"

while [[ $# -gt 0 ]]; do
  case $1 in
    --method) METHOD="$2"; shift 2 ;;
    --sequences) SEQUENCES="$2"; shift 2 ;;
    --N) N="$2"; shift 2 ;;
    --radius) RADIUS="$2"; shift 2 ;;
    --noise-level) NOISE_LEVEL="$2"; shift 2 ;;
    --num-workers) NUM_WORKERS="$2"; shift 2 ;;
    --max-frames) MAX_FRAMES="$2"; shift 2 ;;
    --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
    --method-config) METHOD_CONFIG="$2"; shift 2 ;;
    --save-blended) SAVE_BLENDED="--save-blended"; shift ;;
    --test) MAX_FRAMES="5"; shift ;;
    *) DATA_DIR="$1"; shift ;;
  esac
done

DATA_DIR="${DATA_DIR:-/data}"

echo ""
echo "=============================================="
echo "  Lidar Simulation 2D Benchmark (Docker)"
echo "=============================================="
echo "Method:       $METHOD"
echo "Sequences:    $SEQUENCES"
echo "N:            $N"
echo "Radius:       $RADIUS"
echo "Noise level:  $NOISE_LEVEL"
echo "Workers:      $NUM_WORKERS"
echo "Max frames:   ${MAX_FRAMES:-unlimited}"
echo "Output dir:   $OUTPUT_DIR"
echo "Data dir:     $DATA_DIR"
echo "=============================================="
echo ""

# === 6. Run benchmark ===
python3 lidarSimBenchmarkParallel.py \
  --method "$METHOD" \
  --sequences "$SEQUENCES" \
  --N "$N" \
  --radius "$RADIUS" \
  --noise-level "$NOISE_LEVEL" \
  --num-workers "$NUM_WORKERS" \
  --output-dir "$OUTPUT_DIR" \
  ${MAX_FRAMES:+--max-frames "$MAX_FRAMES"} \
  ${METHOD_CONFIG:+--method-config "$METHOD_CONFIG"} \
  ${SAVE_BLENDED:+--save-blended} \
  "$DATA_DIR"

EXIT_CODE=$?
echo ""
echo "=============================================="
echo "  Benchmark exit code: $EXIT_CODE"
echo "=============================================="
exit $EXIT_CODE
