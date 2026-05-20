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
. /opt/ros/humble/setup.bash
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

# === 2.5 Build pybind11 module for SOFT (ml env) ===
if [ "$METHOD" = "soft" ]; then
  echo ">>> Building pybind11 module for SOFT..."
  pip install pybind11

  PYBIND_INC=$(python -c "import pybind11; print(pybind11.get_include())")
  NUMPY_INC=$(python -c "import numpy; print(numpy.get_include())")
  PY_INCFLAGS=$(python -c "import sysconfig; print(sysconfig.get_paths()['include'])")
  PY_SUFFIX=$(python -c "import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))")

  g++ -O3 -shared -fPIC -std=c++20 \
    -I"${PYBIND_INC}" \
    -I"${NUMPY_INC}" \
    -I"${PY_INCFLAGS}" \
    -I/home/benchmark/ros_ws/src/fsregistration/include \
    -I/home/benchmark/ros_ws/src/fsregistration/find-peaks/include \
    -I/home/benchmark/ros_ws/install/soft20/include \
    -I/usr/include/eigen3 \
    -I/usr/local/include/opencv4 \
    -I/opt/ros/humble/include \
    /home/benchmark/ros_ws/src/fsregistration/src/pybind_registration_3d.cpp \
    /home/benchmark/ros_ws/src/fsregistration/src/softRegistrationClass3D.cpp \
    /home/benchmark/ros_ws/src/fsregistration/src/softCorrelationClass3D.cpp \
    /home/benchmark/ros_ws/src/fsregistration/src/generalHelpfulTools.cpp \
    /home/benchmark/ros_ws/src/fsregistration/find-peaks/src/union_find.cpp \
    /home/benchmark/ros_ws/install/soft20/lib/libsoft20.a \
    -lfftw3 \
    -L/usr/local/lib -lopencv_imgproc -lopencv_highgui -lopencv_core \
    -o "/home/benchmark/ros_ws/src/fsregistration/src/pybind_registration_3d${PY_SUFFIX}"
  echo ">>> pybind11 module built."
fi

# === 2.6 Compile C++ wrappers for regtr_env ===
if [ "$METHOD" = "regtr" ]; then
  echo ">>> Compiling C++ wrappers..."
  bash -c '\
    cd /home/benchmark/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D/predator/cpp_wrappers \
    && bash compile_wrappers.sh' \
    && bash -c '\
    cd /home/benchmark/ros_ws/src/fsregistration/ml_registration/regtr/src/models/backbone_kpconv/cpp_wrappers \
    && bash compile_wrappers.sh'
  echo ">>> C++ wrappers compiled."
fi

cd /home/benchmark/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D

# === 3. Fix config paths ===
sed -i 's|/home/tim-external/dataFolder/3dmatch|/data|g' configFiles/predatorNothing.yaml
sed -i 's|/Users/timhansen/Documents/dataFolder/3dmatch|/data|g' configFiles/predatorNothing.yaml

# === 4. Copy weights from /volume/weights ===
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

# === 5. Run benchmark ===
case "$METHOD" in
  fpfh|icp|geotransformer|regtr|hybridpoint|pointreggpt|soft)
    # Use existing batch scripts
    case "$METHOD" in
      fpfh)            SCRIPT="bashScripts/runFPFH_batch.sh" ;;
      icp)             SCRIPT="bashScripts/runICP_batch.sh" ;;
      geotransformer)  SCRIPT="bashScripts/runGeoTransformer_batch.sh" ;;
      regtr)           SCRIPT="bashScripts/runRegTR_batch.sh" ;;
      hybridpoint)     SCRIPT="bashScripts/runHybridPoint_batch.sh" ;;
      pointreggpt)     SCRIPT="bashScripts/runPointRegGPT_batch.sh" ;;
      soft)            SCRIPT="bashScripts/runSoft_batch.sh" ;;
    esac
    # Fix config filename to use our fixed config
    sed -i 's|predatorNothingMac.yaml|predatorNothing.yaml|g' "$SCRIPT"
    # Fix worker count
    sed -i "s|NUM_WORKERS=.*|NUM_WORKERS=${NUM_WORKERS}|g" "$SCRIPT"
    # Fix total samples for test mode
    if [ "$TEST_MODE" = "--test" ]; then
      sed -i 's|TOTAL_SAMPLES_VAL=.*|TOTAL_SAMPLES_VAL=10|g' "$SCRIPT"
      sed -i 's|TOTAL_SAMPLES_TRAIN=.*|TOTAL_SAMPLES_TRAIN=10|g' "$SCRIPT"
      echo ">>> Test mode: 10 samples per noise/split combo"
    fi
    bash "$SCRIPT"
    ;;
esac

# === 6. Copy results to volume mount ===
if [ -d "outputFiles/$METHOD" ]; then
  mkdir -p /volume/results/"$METHOD"
  cp -r outputFiles/"$METHOD"/* /volume/results/"$METHOD"/ 2>/dev/null || true
fi

echo ""
echo "=============================================="
echo "=== DONE: $METHOD ==="
echo "=============================================="
ls -la /volume/results/"$METHOD"/outfile_*.csv 2>/dev/null || echo "(no output CSV files)"
