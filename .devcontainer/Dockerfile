FROM osrf/ros:humble-desktop-full



ARG USERNAME=tim-external
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.
    && apt update \
    && apt install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME


USER $USERNAME

ENV TZ=Europe/Berlin

RUN sudo apt update && sudo apt upgrade -y
RUN sudo apt install -y python3-pip

RUN sudo apt update && sudo apt install locales
RUN sudo locale-gen de_DE de_DE.UTF-8
RUN sudo update-locale LC_ALL=de_DE.UTF-8 LANG=de_DE.UTF-8
RUN export LANG=de_DE.UTF-8
ARG DEBIAN_FRONTEND=noninteractive

RUN sudo apt install -y ninja-build cmake libopenblas-dev openssh-server wget vim nano htop
RUN sudo apt install -y build-essential pkg-config unzip yasm git checkinstall  # generic tools
RUN sudo apt install -y git libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev  # required
RUN sudo apt install -y python3-dev python3-pip
#python3-numpy
RUN sudo apt install -y python3-testresources
RUN sudo apt install -y libjpeg-dev libpng-dev libtiff-dev
RUN sudo apt install -y libavcodec-dev
RUN sudo apt install -y libavformat-dev
RUN sudo apt install -y libswscale-dev
RUN sudo apt install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
RUN sudo apt install -y libxvidcore-dev x264 libx264-dev libfaac-dev libmp3lame-dev libtheora-dev
RUN sudo apt install -y libfaac-dev libmp3lame-dev libvorbis-dev
RUN sudo apt install -y libopencore-amrnb-dev libopencore-amrwb-dev
RUN sudo apt install -y libgtk-3-dev
RUN sudo apt install -y libtbb2 libtbb-dev
RUN sudo apt install -y libatlas-base-dev gfortran
RUN sudo apt install -y libprotobuf-dev protobuf-compiler
RUN sudo apt install -y libgoogle-glog-dev libgflags-dev
RUN sudo apt install -y libgphoto2-dev libeigen3-dev libhdf5-dev doxygen

RUN python3 -m pip uninstall opencv-python-headless
RUN sudo apt remove python3-opencv -y

RUN sudo apt install pkg-config -y
RUN sudo apt install fftw3 fftw3-dev -y
RUN sudo apt install nlohmann-json3-dev -y
RUN sudo apt install libgtk2.0-dev libgtk-3-dev -y
RUN sudo apt install libqt5gamepad5-dev -y
RUN sudo apt install libtbb-dev -y
RUN sudo apt install libcgal-dev -y
RUN sudo apt install -y libboost-all-dev
RUN sudo apt install software-properties-common -y
RUN sudo add-apt-repository universe -y
RUN sudo apt update && sudo apt install curl -y
RUN sudo apt update -y
RUN sudo apt upgrade -y

COPY ../configFiles/requirements.txt /install_ws/
RUN pip install -r /install_ws/requirements.txt

RUN sudo apt remove libopencv-dev python3-opencv -y
RUN sudo apt purge libopencv-dev python3-opencv -y









WORKDIR /home/$USERNAME/install_ws/opencvInstall

RUN git clone https://github.com/opencv/opencv.git
RUN cd opencv && git checkout 4.9.0
RUN git clone https://github.com/opencv/opencv_contrib.git
RUN cd opencv_contrib && git checkout 4.9.0
RUN #mkdir /install_ws/opencvInstall/build
WORKDIR /home/$USERNAME/install_ws/opencvInstall/build
#building opencv
RUN cmake -DOPENCV_ENABLE_NONFREE:BOOL=ON -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules ../opencv
RUN cmake --build . --config Release -- -j 16
RUN sudo make install





# PCL install
WORKDIR /home/$USERNAME/install_ws
RUN git clone https://github.com/PointCloudLibrary/pcl
WORKDIR /home/$USERNAME/install_ws/pcl
RUN git checkout pcl-1.14.1
WORKDIR /home/$USERNAME/install_ws/pcl/build
RUN cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
RUN make -j 5
RUN sudo make -j 5 install
# gtsam not tested
WORKDIR /home/$USERNAME/install_ws
RUN git clone https://github.com/borglab/gtsam.git
WORKDIR /home/$USERNAME/install_ws/gtsam
RUN git checkout 4.2a7
WORKDIR /home/$USERNAME/install_ws/gtsam/build
RUN cmake .. -DGTSAM_USE_SYSTEM_EIGEN=ON
RUN make -j 10
RUN sudo make install






WORKDIR /home/$USERNAME/

ENV SHELL /bin/bash



# ********************************************************
# * Anything else you want to do like clean up goes here *
# ********************************************************

# [Optional] Set the default user. Omit if you want to keep the default as root.

RUN echo "PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]$\[\033[0m\] ' "  >> ~/.bashrc
RUN #echo "source activate base">> ~/.bashrc
RUN echo "source /opt/ros/humble/setup.bash">> ~/.bashrc
RUN echo "source /home/ws/install/setup.bash">> ~/.bashrc
RUN echo "COLCON_DEFAULTS_FILE=/home/ws/configFiles/defaultColconSettings.yaml">> ~/.bashrc


#ENTRYPOINT ["/bin/bash","PS1='\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]$\[\033[0m\] '"]
CMD ["/bin/bash"]