FROM osrf/ros:humble-desktop-full


#additional

ARG USERNAME=tim-external
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y python3-pip


RUN apt update
RUN apt install pkg-config -y
RUN apt install fftw3 fftw3-dev -y
RUN apt install nlohmann-json3-dev -y
RUN apt install build-essential libgtk2.0-dev libgtk-3-dev -y
RUN apt install libqt5gamepad5-dev -y
RUN apt install libtbb-dev -y
RUN apt install libcgal-dev -y




RUN mkdir /install_ws
RUN mkdir /install_ws/opencvInstall
RUN cd /install_ws/opencvInstall && git clone https://github.com/opencv/opencv.git
RUN cd /install_ws/opencvInstall/opencv && git checkout 4.9.0
RUN cd /install_ws/opencvInstall && git clone https://github.com/opencv/opencv_contrib.git
RUN cd /install_ws/opencvInstall/opencv_contrib && git checkout 4.9.0
RUN mkdir /install_ws/opencvInstall/build
RUN cd /install_ws/opencvInstall/build && cmake -DOPENCV_ENABLE_NONFREE:BOOL=ON -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules ../opencv
RUN cd /install_ws/opencvInstall/build && cmake --build . --config Release -- -j 10
RUN cd /install_ws/opencvInstall/build && sudo make install
# PCL install
RUN cd /install_ws && git clone https://github.com/PointCloudLibrary/pcl
RUN cd /install_ws/pcl && git checkout pcl-1.14.1
RUN mkdir /install_ws/pcl/build
RUN cd /install_ws/pcl/build && cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo ..
RUN cd /install_ws/pcl/build && make -j10
RUN cd /install_ws/pcl/build && sudo make -j10 install
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