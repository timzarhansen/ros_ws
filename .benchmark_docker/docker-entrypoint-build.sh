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
sudo rm -r install/* build/* log/*
colcon build --packages-select soft20 fsregistration
echo ">>> Colcon build complete."

echo ""
echo "=============================================="
echo "  Build complete!"
echo "=============================================="