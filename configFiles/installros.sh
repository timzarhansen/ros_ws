#!/bin/bash
sudo chown -R tim-external /home/tim-external/ros_ws
source /home/tim-external/.bashrc
cd /home/tim-external/ros_ws/
colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release