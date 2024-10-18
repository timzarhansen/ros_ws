For now this is just a list of Stuff, that is important.

folder Stucture: \
ws_[project] \
├── configFiles\
├── cache\
|   ├── [ROS2_DISTRO]\
|   |   ├── build\
|   |   ├── install\
|   |   └── log\
|   └── ...\
|\
├── src\
├── .devcontainer\
│   ├── devcontainer.json\
│   └── Dockerfile\
├── package1\
└── package2\

probably:
```
PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]$\[\033[0m\] '
source /opt/ros/humble/setup.bash
source /home/ws/install/setup.bash



sudo rm -r install/* build/* log/*



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



# local llama opn gpu server 
```
docker run --net=host --gpus=all --rm -v /home/deeprobotics/localDocuments/models/models--bartowski--Qwen2.5-Coder-7B-Instruct-GGUF:/models \
ghcr.io/ggerganov/llama.cpp:server-cuda -m /models/snapshots/1f629da0c8bed16b9e50cee91c70693650e66c35/Qwen2.5-Coder-7B-Instruct-Q8_0.gguf --port 8000 --host 10.70.15.107 -n 512 --n-gpu-layers 1000
```



# PX4
```
git clone https://github.com/timzarhansen/PX4-Autopilot --recursive
cd PX4-Autopilot
git submodule update --recursive
sudo apt install python3-pip -y
bash Tools/setup/ubuntu.sh

make px4_fmu-v5_default
```


