FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy

ARG USERNAME=benchmark
ARG USER_UID=1001
ARG USER_GID=$USER_UID

# === System packages ===
RUN groupadd --gid $USER_GID $USERNAME 2>/dev/null || true \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y --no-install-recommends sudo \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME \
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
        python3-pybind11 \
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
        bubblewrap \
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

# === Remove system OpenCV ===
RUN apt-get remove -y libopencv-dev python3-opencv || true \
    && apt-get purge -y libopencv-dev python3-opencv || true \
    && apt-get autoremove -y

# === ROS2 Jazzy desktop ===
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ros-dev-tools \
        ros-$ROS_DISTRO-desktop \
    && rm -rf /var/lib/apt/lists/*

# === PCL via apt ===
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpcl-dev \
    && rm -rf /var/lib/apt/lists/*

# === Miniforge3 ===
RUN wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh -O /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p /opt/miniforge3 \
    && rm /tmp/miniforge.sh

# === Copy environment files for conda env creation ===
COPY --chown=$USERNAME:$USER_GID .devcontainer/environment.yml /home/$USERNAME/ros_ws/.devcontainer/environment.yml

# === Switch to non-root user ===
USER $USERNAME
WORKDIR /home/$USERNAME

# === Colcon defaults ===
RUN mkdir -p /home/$USERNAME/.colcon \
    && cat > /home/$USERNAME/.colcon_defaults.yaml << 'EOF'
build:
  cmake-args:
    - -DCMAKE_BUILD_TYPE=Release
    - -DPython3_EXECUTABLE=/usr/bin/python3
  symlink-install: true
EOF

# === Shell configuration ===
RUN echo 'PS1="\[\033[1;36m\]\u\[\033[1;31m\]@\[\033[1;32m\]\h:\[\033[1;35m\]\w\[\033[1;31m\]$\[\033[0m\] " ' >> ~/.bashrc

# === Entrypoints ===
COPY --chmod=755 .benchmark_docker/docker-entrypoint-build.sh /usr/local/bin/docker-entrypoint-build.sh
COPY --chmod=755 .benchmark_docker/docker-entrypoint-benchmark.sh /usr/local/bin/docker-entrypoint-benchmark.sh