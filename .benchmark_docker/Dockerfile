FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=humble

ARG USERNAME=benchmark
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# === System packages ===
RUN groupadd --gid $USER_GID $USERNAME 2>/dev/null || true \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        software-properties-common \
        build-essential \
        cmake \
        git \
        wget \
        curl \
        ca-certificates \
        gnupg \
        python3-pip \
        python3-venv \
        python3-dev \
        python3-numpy \
        python3-setuptools \
        libboost-all-dev \
        libeigen3-dev \
        libfftw3-dev \
        nlohmann-json3-dev \
        libqt5gamepad5-dev \
        libcgal-dev \
        unzip \
        nano \
        net-tools \
        nmap \
        tzdata \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        libflann-dev \
        libpng-dev \
        libopenmpi-dev \
        libsdl2-dev \
        libtbb-dev \
        libomp-dev \
        libsystemd-dev \
        locales \
    && locale-gen en_US.UTF-8 \
    && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# === OpenCV 4.9.0 from source ===
WORKDIR /home/$USERNAME/install_ws/opencvInstall
RUN git clone --branch 4.9.0 https://github.com/opencv/opencv.git \
    && git clone --branch 4.9.0 https://github.com/opencv/opencv_contrib.git
WORKDIR /home/$USERNAME/install_ws/opencvInstall/build
RUN cmake -DOPENCV_ENABLE_NONFREE:BOOL=ON \
    -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib/modules \
    -DBUILD_opencv_hdf=OFF \
    -DBUILD_opencv_wechat_qrcode=OFF \
    -DBUILD_opencv_dnn_superres=OFF \
    -DBUILD_opencv_sfm=OFF \
    -DBUILD_opencv_face=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    ../opencv \
    && cmake --build . --parallel $(nproc) \
    && make install \
    && ldconfig

# === PCL 1.14.1 from source ===
WORKDIR /home/$USERNAME/install_ws
RUN git clone --branch pcl-1.14.1 https://github.com/PointCloudLibrary/pcl
WORKDIR /home/$USERNAME/install_ws/pcl/build
RUN cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DBUILD_visualization=ON \
    -DBUILD_apps=OFF \
    -DBUILD_examples=OFF \
    .. \
    && make -j $(nproc) \
    && make install \
    && ldconfig

# === ROS2 Humble desktop ===
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ros-dev-tools \
        ros-$(. /etc/os-release && echo $ROS_DISTRO)-desktop \
    && rm -rf /var/lib/apt/lists/*

# === Miniforge3 ===
RUN wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh -O /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p /opt/miniforge3 \
    && rm /tmp/miniforge.sh

# === Switch to non-root user ===
USER $USERNAME
WORKDIR /home/$USERNAME

# === Entrypoints ===
COPY .benchmark_docker/docker-entrypoint-build.sh /usr/local/bin/docker-entrypoint-build.sh
COPY .benchmark_docker/docker-entrypoint-benchmark.sh /usr/local/bin/docker-entrypoint-benchmark.sh
RUN chmod +x /usr/local/bin/docker-entrypoint-build.sh \
    && chmod +x /usr/local/bin/docker-entrypoint-benchmark.sh
