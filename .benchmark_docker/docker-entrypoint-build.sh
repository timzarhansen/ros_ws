#!/usr/bin/env bash
set -eo pipefail

echo "=============================================="
echo "  fsregistration Benchmark — Build Phase"
echo "=============================================="

# === 1. Source ROS2 ===
. /opt/ros/jazzy/setup.bash

# === 2. Colcon build soft20 + fsregistration ===
echo ">>> Building with colcon..."
cd /home/benchmark/ros_ws
sudo rm -r install/* build/* log/* 2>/dev/null || true
colcon build --packages-select soft20 fsregistration cv_bridge
echo ">>> Colcon build complete."

# === 2.5 Verify Release build type ===
echo ">>> Verifying CMAKE_BUILD_TYPE..."
if grep -q "^CMAKE_BUILD_TYPE:STRING=Release$" build/soft20/CMakeCache.txt && \
   grep -q "^CMAKE_BUILD_TYPE:STRING=Release$" build/fsregistration/CMakeCache.txt; then
  echo ">>> OK: soft20 + fsregistration built with CMAKE_BUILD_TYPE=Release"
else
  echo "ERROR: Packages NOT built with CMAKE_BUILD_TYPE=Release!" >&2
  grep "^CMAKE_BUILD_TYPE" build/soft20/CMakeCache.txt build/fsregistration/CMakeCache.txt >&2 || true
  exit 1
fi

# === 3. Download model weights ===
echo ">>> Downloading model weights..."
cd /home/benchmark/ros_ws/src/fsregistration/weights
bash download_models.sh
echo ">>> Weights downloaded."

echo ""
echo "=============================================="
echo "  Build complete!"
echo "=============================================="