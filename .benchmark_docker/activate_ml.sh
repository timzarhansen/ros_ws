#!/bin/bash
# Activate the ML conda environment
# Usage: source .benchmark_docker/activate_ml.sh
#
# Note: This script also sets LD_LIBRARY_PATH=/usr/local/lib because the
# pybind modules (pybind_registration_3d) link against OpenCV 4.9 libraries
# installed in /usr/local/lib/. Without this, importing the pybind module
# will fail with "libopencv_imgproc.so.409: cannot open shared object file".
source /opt/miniforge3/etc/profile.d/conda.sh
conda activate ml
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH