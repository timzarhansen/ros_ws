For now this is just a list of Stuff, that is important.

folder Stucture: 
ws_[project]
├── configFiles
├── cache
|   ├── [ROS2_DISTRO]
|   |   ├── build
|   |   ├── install
|   |   └── log
|   └── ...
|
├── src
├── .devcontainer
│   ├── devcontainer.json
│   └── Dockerfile
├── package1
└── package2

probably:
```
PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]$\[\033[0m\] '
source /opt/ros/humble/setup.bash
source /home/ws/install/setup.bash

#export RMW_IMPLEMENTATION=rmw_fastrtps_cpp
#export `ROS_DOMAIN_ID`=161
#export COLCON_DEFAULTS_FILE=~/defaultColconSettings.yaml
```

after the setup copy the output of this to the clion environmentVariables
this has to be put in CMake and Run config variables. Else debug wont work
```
ros_env="AMENT_PREFIX_PATH CMAKE_PREFIX_PATH COLCON_PREFIX_PATH PKG_CONFIG_PATH PYTHONPATH LD_LIBRARY_PATH PATH ROS_DISTRO ROS_PYTHON_VERSION ROS_LOCALHOST_ONLY ROS_VERSION"
env_string=""
for e in ${ros_env}; do
env_string+="$e=${!e};"
done
echo "$env_string"
```

