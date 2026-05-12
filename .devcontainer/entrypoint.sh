#!/usr/bin/env bash
set -e

# Source ROS 2 and workspace setup (sets AMENT_PREFIX_PATH, COLCON_PREFIX_PATH, LD_LIBRARY_PATH, PATH)
source /opt/ros/jazzy/setup.bash
[ -f /home/tim-external/ros_ws/install/setup.bash ] && source /home/tim-external/ros_ws/install/setup.bash

# Dynamically compute PYTHONPATH from installed packages
# This replaces the hardcoded PYTHONPATH which breaks when packages are added/removed
compute_pythonpath() {
    local pythonpath=""
    local sep=""

    for dir in "$@"; do
        [ -d "$dir" ] || continue
        while IFS= read -r -d '' p; do
            pythonpath="${pythonpath}${sep}${p}"
            sep=":"
        done < <(find "$dir" -type d \( -path '*/lib/python*/site-packages' -o -path '*/local/lib/python*/dist-packages' \) -print0 2>/dev/null | sort -z)
    done

    echo "$pythonpath"
}

export PYTHONPATH="$(compute_pythonpath /opt/ros/jazzy /home/tim-external/ros_ws/install)"

# Force CMake to use system Python 3.12 (ignore miniforge's Python 3.13)
export Python3_ROOT_DIR=/usr

exec "$@"
