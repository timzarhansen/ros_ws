#!/bin/bash
set -e

echo "=== Post-Create Setup ==="

git config --global user.name "opencode"
git config --global user.email "opencode@zarbokk.me"
git config --global init.defaultBranch main

echo "Setting up Docker access..."
echo "Docker-in-Docker feature already configured docker group"

if [ -d "/home/tim-external/volumeROS/.opencode" ]; then
  cd /home/tim-external/volumeROS/.opencode
  npm install

  echo "✓ .opencode dependencies installed"
fi

curl -fsSL https://opencode.ai/install | bash

# Create conda ML environment from environment.yml
echo "=== Creating conda ML environment ==="
/opt/miniforge3/bin/conda env create -f /home/tim-external/volumeROS/.devcontainer/environment.yml
echo "✓ conda 'ml' environment created"

echo "=== Setup Complete ==="
echo "User: tim-external"
echo "Workspace: /home/tim-external/volumeROS"
echo "Docker: $(docker --version)"
echo "Python: $(python3 --version)"
echo "ROS: $ROS_DISTRO"
echo "Conda: $(/opt/miniforge3/bin/conda --version)"
