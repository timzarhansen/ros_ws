FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ROS_DISTRO=jazzy

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

# === ROS2 Jazzy desktop (includes all deps needed for soft20 build) ===
RUN curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        ros-dev-tools \
        ros-$(. /etc/os-release && echo $ROS_DISTRO)-desktop \
    && rm -rf /var/lib/apt/lists/*

# === soft20 (built via colcon ROS2 workspace) ===
RUN mkdir -p /tmp/soft20_ws/src \
    && git clone https://github.com/Zarbokk/soft20.git /tmp/soft20_ws/src/soft20 \
    && source /opt/ros/jazzy/setup.bash \
    && cd /tmp/soft20_ws \
    && colcon build --packages-select soft20 --cmake-args -DCMAKE_INSTALL_PREFIX=/opt/soft20_install \
    && rm -rf /tmp/soft20_ws

# === Miniforge3 ===
RUN wget -q https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh -O /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p /opt/miniforge3 \
    && rm /tmp/miniforge.sh

# === Copy fsregistration source ===
COPY src/fsregistration /app/fsregistration
COPY .devcontainer/environment.yml /tmp/environment_ml.yml
COPY src/fsregistration/pythonScripts/configFiles/environment_geo.yml /tmp/environment_geo.yml
COPY src/fsregistration/pythonScripts/configFiles/environment_hybridpoint.yml /tmp/environment_hybridpoint.yml
COPY src/fsregistration/pythonScripts/configFiles/environment_pointreggpt.yml /tmp/environment_pointreggpt.yml
COPY src/fsregistration/pythonScripts/configFiles/environment_regtr.yml /tmp/environment_regtr.yml

# === Create conda environments ===
RUN /opt/miniforge3/bin/conda env create -f /tmp/environment_ml.yml \
    && /opt/miniforge3/bin/conda env create -f /tmp/environment_geo.yml \
    && /opt/miniforge3/bin/conda env create -f /tmp/environment_hybridpoint.yml \
    && /opt/miniforge3/bin/conda env create -f /tmp/environment_pointreggpt.yml \
    && /opt/miniforge3/bin/conda env create -f /tmp/environment_regtr.yml

# === Build pybind11 module for SOFT (ml env, Python 3.12) ===
RUN /opt/miniforge3/envs/ml/bin/pip install pybind11 \
    && PYBIND_INC=$(/opt/miniforge3/envs/ml/bin/python -c "import pybind11; print(pybind11.get_include())") \
    && NUMPY_INC=$(/opt/miniforge3/envs/ml/bin/python -c "import numpy; print(numpy.get_include())") \
    && PY_INCFLAGS=$(/opt/miniforge3/envs/ml/bin/python -c "import sysconfig; print(sysconfig.get_paths()['include'])") \
    && PY_SUFFIX=$(/opt/miniforge3/envs/ml/bin/python -c "import sysconfig; print(sysconfig.get_config_var('EXT_SUFFIX'))") \
    && /opt/miniforge3/envs/ml/bin/g++ -O3 -shared -fPIC -std=c++20 \
        -I"${PYBIND_INC}" \
        -I"${NUMPY_INC}" \
        -I"${PY_INCFLAGS}" \
        -I/app/fsregistration/include \
        -I/app/fsregistration/find-peaks/include \
        -I/opt/soft20_install/include \
        -I/opt/soft20_install/include/soft20 \
        -I/usr/include/eigen3 \
        -I/usr/local/include/opencv4 \
        /app/fsregistration/src/pybind_registration_3d.cpp \
        /app/fsregistration/src/softRegistrationClass3D.cpp \
        /app/fsregistration/src/softCorrelationClass3D.cpp \
        /app/fsregistration/src/generalHelpfulTools.cpp \
        /app/fsregistration/find-peaks/src/union_find.cpp \
        /opt/soft20_install/lib/libsoft20.a \
        -lfftw3 \
        -L/usr/local/lib -lopencv_imgproc -lopencv_highgui -lopencv_core \
        -o "/app/fsregistration/src/pybind_registration_3d${PY_SUFFIX}"

# === Compile C++ wrappers for regtr_env ===
RUN /opt/miniforge3/envs/regtr_env/bin/bash -c '\
    cd /app/fsregistration/pythonScripts/matchingProfiling3D/predator/cpp_wrappers \
    && bash compile_wrappers.sh' \
    && /opt/miniforge3/envs/regtr_env/bin/bash -c '\
    cd /app/fsregistration/ml_registration/regtr/src/models/backbone_kpconv/cpp_wrappers \
    && bash compile_wrappers.sh'

# === Cleanup build artifacts ===
RUN rm -rf /home/$USERNAME/install_ws \
    && rm -rf /tmp/environment_*.yml \
    && rm -rf /app/fsregistration/debug_results \
    && chown -R $USERNAME:$USERNAME /app/fsregistration

# === Switch to non-root user ===
USER $USERNAME
WORKDIR /home/$USERNAME

# === Entrypoint ===
COPY .benchmark_docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
