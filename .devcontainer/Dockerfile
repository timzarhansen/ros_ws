FROM ubuntu:22.04



ARG USERNAME=tim-external
ARG USER_UID=1001
ARG USER_GID=$USER_UID
#ARG DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble
ENV ROS_LOCALHOST_ONLY=1
ENV ROS_DOMAIN_ID=161

#ARG DEBIAN_FRONTEND=noninteractive
# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to istall software after connecting.
    && apt update \
    && apt install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME


USER $USERNAME



WORKDIR /home/$USERNAME/install_ws

#ROS
RUN sudo DEBIAN_FRONTEND=noninteractive sudo apt update && sudo apt install locales
RUN sudo DEBIAN_FRONTEND=noninteractive sudo locale-gen de_DE de_DE.UTF-8
RUN sudo DEBIAN_FRONTEND=noninteractive sudo update-locale LC_ALL=de_DE.UTF-8 LANG=de_DE.UTF-8
RUN export LANG=de_DE.UTF-8
RUN sudo DEBIAN_FRONTEND=noninteractive sudo apt-get install -y tzdata




RUN sudo DEBIAN_FRONTEND=noninteractive sudo apt install software-properties-common -y
RUN sudo DEBIAN_FRONTEND=noninteractive sudo add-apt-repository universe
RUN sudo DEBIAN_FRONTEND=noninteractive sudo apt update && sudo apt install curl -y
RUN sudo DEBIAN_FRONTEND=noninteractive sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg
RUN echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
RUN sudo DEBIAN_FRONTEND=noninteractive sudo apt update
RUN sudo DEBIAN_FRONTEND=noninteractive sudo apt install ros-dev-tools -y
RUN sudo DEBIAN_FRONTEND=noninteractive sudo apt upgrade
RUN sudo DEBIAN_FRONTEND=noninteractive sudo apt install ros-$ROS_DISTRO-desktop -y
#RUN source /opt/ros/$ROS_DISTRO/setup.bash


RUN sudo apt remove libopencv-dev python3-opencv -y
RUN sudo apt purge libopencv-dev python3-opencv -y
#opencv
WORKDIR /home/$USERNAME/install_ws/opencvInstall

RUN git clone https://github.com/opencv/opencv.git
RUN cd opencv && git checkout 4.9.0
RUN git clone https://github.com/opencv/opencv_contrib.git
RUN cd opencv_contrib && git checkout 4.9.0
RUN #mkdir /install_ws/opencvInstall/build
WORKDIR /home/$USERNAME/install_ws/opencvInstall/build

RUN cmake -DOPENCV_ENABLE_NONFREE:BOOL=ON -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules ../opencv
RUN cmake --build . --config Release -- -j 16
RUN sudo DEBIAN_FRONTEND=noninteractive sudo make install


RUN sudo DEBIAN_FRONTEND=noninteractive sudo apt install -y libboost-all-dev
#gtsam
WORKDIR /home/$USERNAME/install_ws
RUN git clone https://github.com/borglab/gtsam.git
WORKDIR /home/$USERNAME/install_ws/gtsam
RUN git checkout 4.2a7
WORKDIR /home/$USERNAME/install_ws/gtsam/build
RUN cmake .. -DGTSAM_USE_SYSTEM_EIGEN=ON
RUN make -j 10
RUN sudo DEBIAN_FRONTEND=noninteractive sudo make install
# PCL install
WORKDIR /home/$USERNAME/install_ws
RUN git clone https://github.com/PointCloudLibrary/pcl
WORKDIR /home/$USERNAME/install_ws/pcl
RUN git checkout pcl-1.14.1
WORKDIR /home/$USERNAME/install_ws/pcl/build
RUN cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
RUN make -j 16
RUN sudo DEBIAN_FRONTEND=noninteractive sudo make -j 16 install


# custom stuff
RUN #sudo apt-get update && sudo apt-get -y install python3 python3-pip
RUN sudo DEBIAN_FRONTEND=noninteractive sudo apt-get update && sudo apt-get -y install python3-pip
RUN sudo apt install fftw3 fftw3-dev -y
RUN sudo apt install nlohmann-json3-dev -y
RUN sudo apt install libqt5gamepad5-dev -y
RUN sudo apt install libcgal-dev -y

COPY configFiles/requirements.txt /home/$USERNAME/install_ws
RUN sudo pip install -r /home/$USERNAME/install_ws/requirements.txt
#RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

#COPY otherPackages/PX4-Autopilot/Tools/setup/ubuntu.sh /home/$USERNAME/install_ws
WORKDIR /home/$USERNAME/install_ws


RUN sudo DEBIAN_FRONTEND=noninteractive sudo rosdep init && sudo rosdep update --rosdistro $ROS_DISTRO # buildkit

WORKDIR /home/$USERNAME/
#ENV ROS_DISTRO=humble
ENV SHELL=/bin/bash


COPY configFiles/defaults.yaml /home/$USERNAME/.colcon/defaults.yaml
RUN echo "PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]$\[\033[0m\] ' "  >> ~/.bashrc
RUN #echo "source activate base">> ~/.bashrc
RUN #echo "COLCON_DEFAULTS_FILE=/home/$USERNAME/ros_ws/configFiles/defaultColconSettings.yaml">> ~/.bashrc
RUN echo "source /opt/ros/humble/setup.bash">> ~/.bashrc
RUN echo "source /home/tim-external/ros_ws/install/setup.bash">> ~/.bashrc
#COPY . /home/$USERNAME/ros_ws

#WORKDIR /home/$USERNAME/ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/
#RUN sudo chmod a+x /home/$USERNAME/ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input1.sh
#RUN sudo chmod a+x /home/$USERNAME/ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input2.sh
#RUN sudo chmod a+x /home/$USERNAME/ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input3.sh
#RUN sudo chmod a+x /home/$USERNAME/ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input4.sh
#RUN sudo chmod a+x /home/$USERNAME/ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input5.sh
#RUN sudo chmod a+x /home/$USERNAME/ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input6.sh
#RUN sudo chmod a+x /home/$USERNAME/ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input7.sh
#RUN sudo chmod a+x /home/$USERNAME/ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input8.sh

CMD ["/bin/bash"]

#WORKDIR /home/$USERNAME/
#ENTRYPOINT ["./home/tim-external/ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/workstation_run.sh"]
#ENTRYPOINT ["./home/tim-external/ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input1.sh"]

# export ROS_LOCALHOST_ONLY=1
# export ROS_DOMAIN_ID=161
# docker run example comes Here:

# docker buildx build -t fs3d_benchmark --file .devcontainer/Dockerfile .
# docker run fs3d_benchmark:latest
# --entrypoint "./ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input1.sh" \
#docker run --rm -t -i --user tim-external --ipc=host --name run1 \
#  --entrypoint /bin/bash \
#docker run --rm -t -i -d --ipc=host --name run1 \
#--entrypoint "./ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input1.sh" \
# -v /home/deeprobotics/dataFolder/3dmatch:/home/tim-external/dataFolder/3dmatch:z \
# -v /home/deeprobotics/ros_ws/cache/humble/build:/home/tim-external/ros_ws/build:z \
# -v /home/deeprobotics/ros_ws/cache/humble/install:/home/tim-external/ros_ws/install:z \
# -v /home/deeprobotics/ros_ws/cache/humble/log:/home/tim-external/ros_ws/log:z \
# -v /home/deeprobotics/ros_ws/configFiles:/home/tim-external/ros_ws/configFiles:z \
# -v /home/deeprobotics/localDocuments/matlabMatchingFiles:/home/tim-external/matlab:z \
# -v /home/deeprobotics/ros_ws/src:/home/tim-external/ros_ws/src:z \
# fs3d_benchmark:latest
##
##
#docker run --rm -t -i --ipc=host --name run1 \
#--entrypoint /bin/bash -v /home/deeprobotics/dataFolder/3dmatch:/home/tim-external/dataFolder/3dmatch:z \
# -v /home/deeprobotics/ros_ws/cache/humble/build:/home/tim-external/ros_ws/build:z \
# -v /home/deeprobotics/ros_ws/cache/humble/install:/home/tim-external/ros_ws/install:z \
# -v /home/deeprobotics/ros_ws/cache/humble/log:/home/tim-external/ros_ws/log:z \
# -v /home/deeprobotics/ros_ws/configFiles:/home/tim-external/ros_ws/configFiles:z \
# -v /home/deeprobotics/localDocuments/matlabMatchingFiles:/home/tim-external/matlab:z \
# -v /home/deeprobotics/ros_ws/src:/home/tim-external/ros_ws/src:z \
# fs3d_benchmark:latest


# colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release
# colcon build --packages-select fsregistration --event-handlers console_direct+ --cmake-args -DCMAKE_VERBOSE_MAKEFILE=ON
#
#
# "./ros_ws/src/fsregistration/pythonScripts/matchingProfiling/runScripts/allRunScripts/input2.sh"
