#!/usr/bin/env bash
set -e

# Source ROS 2 and workspace setup
source /opt/ros/jazzy/setup.bash
[ -f /home/tim-external/ros_ws/install/setup.bash ] && source /home/tim-external/ros_ws/install/setup.bash

# Dynamically compute PYTHONPATH from installed packages
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

# Add OpenCV 4.9 libraries to library path (needed for pybind modules)
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Fast DDS discovery server for LAN reachability (macOS Docker Desktop)
export ROS_DISCOVERY_SERVER=127.0.0.1:11811
fastdds discovery -i 0 -l 0.0.0.0 -p 11811 &

exec "$@"
