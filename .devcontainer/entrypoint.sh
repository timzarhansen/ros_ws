#!/usr/bin/env bash
set -e

# --- Deactivate conda base so it doesn't shadow system Python ---
conda deactivate 2>/dev/null || true

# --- Remove conda from PATH so CMake finds system Python ---
# (keeps conda binary accessible at /opt/miniforge3/bin/conda for on-demand use)
export PATH="$(echo "$PATH" | tr ':' '\n' | grep -v -E 'miniforge|conda' | tr '\n' ':' | sed 's/:$//')"

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

# Force CMake to use system Python 3.12 with NumPy
export Python3_ROOT_DIR=/usr

# Dynamically find NumPy include dirs for the system Python
PYTHON_NUMPY_INCLUDE=$(python3 -c "import numpy; print(numpy.get_include())" 2>/dev/null || echo "")
if [ -n "$PYTHON_NUMPY_INCLUDE" ]; then
    export Python3_NumPy_INCLUDE_DIRS="$PYTHON_NUMPY_INCLUDE"
fi

exec "$@"
