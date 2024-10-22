#!/usr/bin/env bash

echo "Hello from our entrypoint!"
source /opt/ros/humble/setup.bash
. /opt/ros/humble/setup.bash
exec "$@"
