#!/usr/bin/env bash
set -e

# Source conda so 'conda activate ml' works (but conda is not on PATH)
if [ -f /opt/miniforge3/etc/profile.d/conda.sh ]; then
    . /opt/miniforge3/etc/profile.d/conda.sh
fi

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

exec "$@"
