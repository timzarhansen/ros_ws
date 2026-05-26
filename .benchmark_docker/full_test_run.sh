#!/usr/bin/env bash
set -euo pipefail
bash .benchmark_docker/cleanup_before_benchmark.sh
git stash
git pull
cd src/fsregistration
git stash
cd ..
cd ..
cd ..
sudo chmod -R 777 ros_ws/
cd ros_ws/
bash .benchmark_docker/run_test.sh


