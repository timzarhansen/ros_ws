#!/usr/bin/env bash
set -eo pipefail

METHOD="${1:-}"
NUM_WORKERS="${2:-8}"
TEST_MODE="${3:-}"

if [ -z "$METHOD" ]; then
  echo "Usage: $0 <method> [num_workers] [--test]"
  echo "Methods: soft fpfh icp geotransformer regtr hybridpoint pointreggpt"
  exit 1
fi

# === Verify build artifacts exist ===
if [ ! -d /home/benchmark/ros_ws/install/soft20 ]; then
  echo "ERROR: soft20 not built. Run 'docker-entrypoint-build.sh' first."
  exit 1
fi

# === 1. Source ROS2 + workspace ===
. /opt/ros/jazzy/setup.bash
. /home/benchmark/ros_ws/install/setup.bash

# === 2. Create and activate correct conda env ===
source /opt/miniforge3/etc/profile.d/conda.sh
case "$METHOD" in
  soft)
    ENV_NAME=ml
    ENV_FILE=/home/benchmark/ros_ws/.devcontainer/environment.yml
    ;;
  fpfh|icp|geotransformer)
    ENV_NAME=geo_env
    ENV_FILE=/home/benchmark/ros_ws/src/fsregistration/pythonScripts/configFiles/environment_geo_env.yml
    ;;
  hybridpoint)
    ENV_NAME=hybridpoint_env
    ENV_FILE=/home/benchmark/ros_ws/src/fsregistration/pythonScripts/configFiles/environment_hybridpoint_env.yml
    ;;
  pointreggpt)
    ENV_NAME=pointreggpt_env
    ENV_FILE=/home/benchmark/ros_ws/src/fsregistration/pythonScripts/configFiles/environment_pointreggpt_env.yml
    ;;
  regtr)
    ENV_NAME=regtr_env
    ENV_FILE=/home/benchmark/ros_ws/src/fsregistration/pythonScripts/configFiles/environment_regtr_env.yml
    ;;
  *) echo "Unknown method: $METHOD"; exit 1 ;;
esac

if conda env list | grep -q "^${ENV_NAME} "; then
  echo ">>> Conda env $ENV_NAME exists, activating..."
else
  echo ">>> Creating conda env $ENV_NAME..."
  conda env create -f "$ENV_FILE"
fi

conda activate "$ENV_NAME"

# === 2.5 Set LD_LIBRARY_PATH for OpenCV 4.9 (soft method only) ===
if [ "$METHOD" = "soft" ]; then
  export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
  echo ">>> LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
fi

# === 2.6 Set PYTHONPATH for pybind11 module (soft method only) ===
if [ "$METHOD" = "soft" ]; then
  export PYTHONPATH="/home/benchmark/ros_ws/install/fsregistration/lib/fsregistration:$PYTHONPATH"
  echo ">>> PYTHONPATH=$PYTHONPATH"
fi

# === 2.7 Compile C++ wrappers for regtr_env and soft ===
if [ "$METHOD" = "soft" ] || [ "$METHOD" = "regtr" ]; then
  echo ">>> Compiling predator C++ wrappers..."
  bash -c '\
    cd /home/benchmark/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D/predator/cpp_wrappers \
    && bash compile_wrappers.sh'
  if [ "$METHOD" = "regtr" ]; then
    bash -c '\
    cd /home/benchmark/ros_ws/src/fsregistration/ml_registration/regtr/src/models/backbone_kpconv/cpp_wrappers \
    && bash compile_wrappers.sh'
  fi
  echo ">>> C++ wrappers compiled."
fi

cd /home/benchmark/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D

# === 3. Fix worker count ===
sed -i "s|NUM_WORKERS=.*|NUM_WORKERS=${NUM_WORKERS}|g" bashScripts/run*.sh

# === 4. Fix total samples for test mode ===
if [ "$TEST_MODE" = "--test" ]; then
  sed -i 's|TOTAL_SAMPLES_VAL=.*|TOTAL_SAMPLES_VAL=10|g' bashScripts/run*.sh
  sed -i 's|TOTAL_SAMPLES_TRAIN=.*|TOTAL_SAMPLES_TRAIN=10|g' bashScripts/run*.sh
  echo ">>> Test mode: 10 samples per noise/split combo"
fi

# === 5. Copy weights from /volume/weights ===
if [ -f /volume/weights/regtr-3dmatch-model-best.pth ]; then
  mkdir -p /home/benchmark/ros_ws/src/fsregistration/ml_registration/regtr/trained_models/3dmatch/ckpt/
  cp /volume/weights/regtr-3dmatch-model-best.pth \
    /home/benchmark/ros_ws/src/fsregistration/ml_registration/regtr/trained_models/3dmatch/ckpt/model-best.pth
  echo "Copied RegTR weights"
fi

if [ -f /volume/weights/hybridpoint-3dmatch.tar ]; then
  mkdir -p /home/benchmark/ros_ws/src/fsregistration/ml_registration/hybridpoint/weights_for_hybrid/
  cp /volume/weights/hybridpoint-3dmatch.tar \
    /home/benchmark/ros_ws/src/fsregistration/ml_registration/hybridpoint/weights_for_hybrid/3dmatch.tar
  echo "Copied HybridPoint weights"
fi

if [ -f /volume/weights/predator-indoor.pth ]; then
  mkdir -p /data/models/predator/data/weights/
  cp /volume/weights/predator-indoor.pth /data/models/predator/data/weights/indoor.pth
  echo "Copied Predator weights"
fi

# === 6. Run benchmark ===
case "$METHOD" in
  fpfh|icp|geotransformer|regtr|hybridpoint|pointreggpt|soft)
    case "$METHOD" in
      fpfh)            SCRIPT="bashScripts/runFPFH_batch.sh" ;;
      icp)             SCRIPT="bashScripts/runICP_batch.sh" ;;
      geotransformer)  SCRIPT="bashScripts/runGeoTransformer_batch.sh" ;;
      regtr)           SCRIPT="bashScripts/runRegTR_batch.sh" ;;
      hybridpoint)     SCRIPT="bashScripts/runHybridPoint_batch.sh" ;;
      pointreggpt)     SCRIPT="bashScripts/runPointRegGPT_batch.sh" ;;
      soft)            SCRIPT="bashScripts/runSoft_batch.sh" ;;
    esac
    bash "$SCRIPT"
    ;;
esac

# === 7. Copy results to volume mount ===
if [ -d "outputFiles/$METHOD" ]; then
  mkdir -p /volume/results/"$METHOD"
  cp -r outputFiles/"$METHOD"/* /volume/results/"$METHOD"/ 2>/dev/null || true
fi

echo ""
echo "=============================================="
echo "=== DONE: $METHOD ==="
echo "=============================================="
ls -la /volume/results/"$METHOD"/outfile_*.csv 2>/dev/null || echo "(no output CSV files)"