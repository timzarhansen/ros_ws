#!/usr/bin/env bash
set -eo pipefail

echo "=============================================="
echo "  fsregistration Benchmark — Build Phase"
echo "=============================================="

# === 1. Source ROS2 ===
. /opt/ros/humble/setup.bash

# === 2. Install pybind11 for CMake ===
pip install pybind11 pybind11[global]

# === 3. Colcon build soft20 + fsregistration ===
echo ">>> Building with colcon..."
cd /home/benchmark/ros_ws
sudo rm -r install/* build/* log/*
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release --packages-select soft20 fsregistration
echo ">>> Colcon build complete."

# === 4. Compile predator C++ wrappers ===
echo ">>> Compiling predator C++ wrappers..."
cd /home/benchmark/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D/predator/cpp_wrappers
bash compile_wrappers.sh
echo ">>> Predator C++ wrappers compiled."

echo ""
echo "=============================================="
echo "  Build complete!"
echo "=============================================="
