#!/bin/bash

sudo rm -r ros_ws/
git clone https://github.com/timzarhansen/ros_ws.git
cd ros_ws/
git submodule update --init --recursive

docker run --rm --ipc=host -v /home/deeprobotics/ros_ws/cache/humble/build:/home/tim-external/ros_ws/build -v /home/deeprobotics/ros_ws/cache/humble/install:/home/tim-external/ros_ws/install -v /home/deeprobotics/ros_ws/cache/humble/log:/home/tim-external/ros_ws/log -v /home/deeprobotics/ros_ws/configFiles:/home/tim-external/ros_ws/configFiles -v /home/deeprobotics/ros_ws/src:/home/tim-external/ros_ws/src -v /home/deeprobotics/dataFolder:/home/tim-external/dataFolder --entrypoint "source /home/tim-external/ros_ws/configFiles/installROS.sh"  computationimageodometryamd
#docker run -t -i --rm --ipc=host -v /home/deeprobotics/ros_ws/cache/humble/build:/home/tim-external/ros_ws/build -v /home/deeprobotics/ros_ws/cache/humble/install:/home/tim-external/ros_ws/install -v /home/deeprobotics/ros_ws/cache/humble/log:/home/tim-external/ros_ws/log -v /home/deeprobotics/ros_ws/configFiles:/home/tim-external/ros_ws/configFiles -v /home/deeprobotics/ros_ws/src:/home/tim-external/ros_ws/src -v /home/deeprobotics/dataFolder:/home/tim-external/dataFolder computationimageodometryamd
#sudo chown -R tim-external /home/tim-external/ros_ws
#cd ros_ws/
#colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
#exit









