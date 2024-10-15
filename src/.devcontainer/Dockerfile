#FROM rospytorchcudnn
#FROM pytorch/pytorch:2.3.1-cuda11.8-cudnn8-devel
FROM osrf/ros:humble-desktop-full
ENV TZ=Europe/Berlin \
    DEBIAN_FRONTEND=noninteractive
RUN apt-get update
RUN apt-get install -y git ninja-build cmake build-essential libopenblas-dev \
    xterm xauth openssh-server tmux wget mate-desktop-environment-core vim nano
RUN apt-get update && apt-get install --no-install-recommends -y libegl1 libgl1 libgomp1
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y python3-pip


RUN apt update
RUN apt install pkg-config git -y
RUN apt install fftw3 fftw3-dev -y
RUN apt install nlohmann-json3-dev -y
RUN apt install build-essential libgtk2.0-dev libgtk-3-dev -y
RUN apt install libqt5gamepad5-dev -y
RUN apt install libtbb-dev -y
RUN apt install libcgal-dev -y
RUN apt install libeigen3-dev -y
RUN apt install -y g++ cmake cmake-gui doxygen mpi-default-dev openmpi-bin openmpi-common
RUN apt install -y libusb-1.0-0-dev libqhull* libusb-dev libgtest-dev
RUN apt install -y git-core freeglut3-dev pkg-config build-essential libxmu-dev libxi-dev
RUN apt install -y libflann-dev

RUN apt install -y libflann1.9
RUN apt install -y libboost-dev
RUN apt install -y libeigen3-dev
RUN apt install -y vtk9
RUN apt install -y python3-vtk9
RUN apt install -y libboost-all-dev
RUN apt install -y libhdf5-dev
RUN apt install -y cmake git libgtk2.0-dev pkg-config libavcodec-dev libavformat-dev libswscale-dev


RUN mkdir /install_ws
RUN mkdir /install_ws/opencvInstall
RUN cd /install_ws/opencvInstall && git clone https://github.com/opencv/opencv.git
RUN cd /install_ws/opencvInstall/opencv && git checkout 4.9.0
RUN cd /install_ws/opencvInstall && git clone https://github.com/opencv/opencv_contrib.git
RUN cd /install_ws/opencvInstall/opencv_contrib && git checkout 4.9.0
RUN mkdir /install_ws/opencvInstall/build
RUN cd /install_ws/opencvInstall/build && cmake -DCMAKE_VERBOSE_MAKEFILE:BOOL=ON -DOPENCV_ENABLE_NONFREE:BOOL=ON -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules ../opencv
RUN cd /install_ws/opencvInstall/build && cmake --build . --config Release -- -j 10
RUN cd /install_ws/opencvInstall/build && sudo make install
#
#
#
#
#RUN #apt-get clean
#RUN #rm -rf /var/lib/apt/lists/*
#
#
## PCL install
#RUN cd /install_ws && git clone https://github.com/PointCloudLibrary/pcl
#RUN cd /install_ws/pcl && git checkout pcl-1.14.1
#RUN mkdir /install_ws/pcl/build
#RUN cd /install_ws/pcl/build && cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
#RUN cd /install_ws/pcl/build && make -j10
#RUN cd /install_ws/pcl/build && sudo make -j10 install
# gtsam not tested
#RUN cd /install_ws && git clone https://github.com/borglab/gtsam.git
#RUN cd /install_ws/gtsam && git checkout 4.2a7
#RUN mkdir /install_ws/gtsam/build
#RUN cd /install_ws/gtsam/build && cmake .. -DGTSAM_USE_SYSTEM_EIGEN=ON
#RUN cd /install_ws/gtsam/build && make
#RUN cd /install_ws/gtsam/build && sudo make install




ENV SHELL /bin/bash

# ********************************************************
# * Anything else you want to do like clean up goes here *
# ********************************************************

# [Optional] Set the default user. Omit if you want to keep the default as root.
USER $USERNAME
CMD ["/bin/bash"]