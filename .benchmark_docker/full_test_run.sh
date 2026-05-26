#!/usr/bin/env bash
set -euo pipefail
bash .benchmark_docker/cleanup_before_benchmark.sh
git stash
git pull
git -C src/fsregistration stash
sudo chmod -R 777 .
bash .benchmark_docker/run_test.sh


