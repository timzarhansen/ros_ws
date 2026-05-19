#!/usr/bin/env bash
set -euo pipefail

echo "=============================================="
echo "  fsregistration Benchmark — Build Phase"
echo "=============================================="

# === 1. Source ROS2 ===
. /opt/ros/humble/setup.bash

# === 2. Colcon build soft20 + fsregistration ===
echo ">>> Building with colcon..."
cd /home/benchmark/ros_ws
colcon build --packages-select soft20 fsregistration
echo ">>> Colcon build complete."

# === 3. Create conda environments ===
echo ">>> Creating conda environments..."
source /opt/miniforge3/etc/profile.d/conda.sh

for env_file in /home/benchmark/ros_ws/src/fsregistration/pythonScripts/configFiles/environment_*.yml; do
  env_name=$(grep "^name:" "$env_file" | awk '{print $2}')
  if conda env list | grep -q "^${env_name} "; then
    echo "  $env_name — already exists, skipping"
  else
    echo "  Creating $env_name..."
    conda env create -f "$env_file"
  fi
done
echo ">>> Conda environments ready."

# === 4. Build pybind11 module for SOFT (ml env) ===
echo ">>> Building pybind11 module for SOFT..."
/opt/miniforge3/envs/ml/bin/pip install pybind11

PYBIND_INC=$(/opt/miniforge3/envs/ml/bin/python -c "import pybind11; print(pybind11.get_include())")
NUMPY_INC=$(/opt/miniforge3/envs/ml/bin/python -c "import numpy; print(numpy.get_include())")
PY_INCFLAGS=$(/opt/miniforge3/envs/ml/bin/python -c "import sysconfig; print(sysconfig.get_paths()['include'])")
PY_SUFFIX=$(/opt/miniforge3/envs/ml/bin/python -c "import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))")

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

# === 5. Compile C++ wrappers for regtr_env ===
echo ">>> Compiling C++ wrappers..."
/opt/miniforge3/envs/regtr_env/bin/bash -c '\
  cd /home/benchmark/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D/predator/cpp_wrappers \
  && bash compile_wrappers.sh' \
  && /opt/miniforge3/envs/regtr_env/bin/bash -c '\
  cd /home/benchmark/ros_ws/src/fsregistration/ml_registration/regtr/src/models/backbone_kpconv/cpp_wrappers \
  && bash compile_wrappers.sh'
echo ">>> C++ wrappers compiled."

echo ""
echo "=============================================="
echo "  Build complete!"
echo "=============================================="
