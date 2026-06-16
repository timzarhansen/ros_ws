#!/bin/bash
set -e

echo "=== Post-Create Setup ==="

git config --global user.name "opencode"
git config --global user.email "opencode@zarbokk.me"
git config --global init.defaultBranch main

echo "Setting up Docker access..."
echo "Docker-in-Docker feature already configured docker group"

if [ -d "/home/tim-external/ros_ws/.opencode" ]; then
  cd /home/tim-external/ros_ws/.opencode
  npm install

  echo "✓ .opencode dependencies installed"
fi

curl -fsSL https://opencode.ai/install | bash

# Setup pi-agent
if [ -d "/pi-agent" ]; then
  echo "Setting up pi-agent..."
  cd /pi-agent

  if [ ! -d "packages/coding-agent/dist" ]; then
    echo "Installing pi-agent dependencies..."
    npm install --ignore-scripts
    echo "Building pi-agent..."
    npm run build
    echo "✓ pi-agent built"
  else
    echo "✓ pi-agent already built"
  fi

  sudo npm install -g /pi-agent/packages/coding-agent
  grep -q "pi-agent" /home/tim-external/.profile || echo 'export PATH="/pi-agent/packages/coding-agent/dist:$PATH"' >> /home/tim-external/.profile
  echo "✓ pi-agent installed globally"
else
  echo "⚠ pi-agent not found at /pi-agent"
  echo "  Mount /pi-agent on the host to use pi-agent in this container"
fi

# Create conda ML environment from environment.yml
echo "=== Creating conda ML environment ==="
/opt/miniforge3/bin/conda env create -f /home/tim-external/ros_ws/.devcontainer/environment.yml
echo "✓ conda 'ml' environment created"

# Compile predator C++ wrappers (needed for testingSoftOnPredatorData.py)
echo "=== Compiling predator C++ wrappers ==="
cd /home/tim-external/ros_ws/src/fsregistration/pythonScripts/matchingProfiling3D/predator/cpp_wrappers
bash compile_wrappers.sh
echo "✓ Predator C++ wrappers compiled"

echo "=== Setup Complete ==="
echo "User: tim-external"
echo "Workspace: /home/tim-external/ros_ws"
echo "Docker: $(docker --version)"
echo "Python: $(python3 --version)"
echo "ROS: $ROS_DISTRO"
echo "Conda: $(/opt/miniforge3/bin/conda --version)"
