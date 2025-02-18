#!/bin/bash

sudo rm -r ros_ws/
git clone https://github.com/timzarhansen/ros_ws.git
cd ros_ws/
git submodule update --init --recursive

#docker run -t -i --rm --ipc=host -v /home/deeprobotics/ros_ws/cache/humble/build:/home/tim-external/ros_ws/build -v /home/deeprobotics/ros_ws/cache/humble/install:/home/tim-external/ros_ws/install -v /home/deeprobotics/ros_ws/cache/humble/log:/home/tim-external/ros_ws/log -v /home/deeprobotics/ros_ws/configFiles:/home/tim-external/ros_ws/configFiles -v /home/deeprobotics/ros_ws/src:/home/tim-external/ros_ws/src -v /home/deeprobotics/dataFolder:/home/tim-external/dataFolder --entrypoint /bin/bash computationimageodometryamd -c 'source ros_ws/configFiles/installros.sh'
docker run -t -i --rm --ipc=host -v /home/nuc01/ros_ws/cache/humble/build:/home/tim-external/ros_ws/build -v /home/nuc01/ros_ws/cache/humble/install:/home/tim-external/ros_ws/install -v /home/nuc01/ros_ws/cache/humble/log:/home/tim-external/ros_ws/log -v /home/nuc01/ros_ws/configFiles:/home/tim-external/ros_ws/configFiles -v /home/nuc01/ros_ws/src:/home/tim-external/ros_ws/src -v /home/nuc01/dataFolder:/home/tim-external/dataFolder --entrypoint /bin/bash computationimageodometryamd -c 'source ros_ws/configFiles/installros.sh'










