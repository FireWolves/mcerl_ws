# 使用Ubuntu 22.04作为基础镜像
FROM ubuntu:22.04

# 避免交互提示并更新系统
ENV DEBIAN_FRONTEND=noninteractive

# 更换源并安装基本工具
RUN sed -i 's|http://archive.ubuntu.com/ubuntu/|http://mirror.zju.edu.cn/ubuntu/|g' /etc/apt/sources.list && \
    apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    build-essential sudo cmake git wget unzip pkg-config software-properties-common \
    libtbb-dev libtbb2 libboost-dev libspdlog-dev \
    python3 python3-pip python3-venv python3-dev \
    libjpeg-dev libpng-dev libtiff-dev libavcodec-dev libavformat-dev libswscale-dev \
    libv4l-dev libxvidcore-dev libx264-dev libgtk-3-dev libatlas-base-dev gfortran && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 下载并编译OpenCV
RUN cd /opt && \
    git clone https://github.com/opencv/opencv.git && \
    git clone https://github.com/opencv/opencv_contrib.git && \
    cd /opt/opencv && \
    mkdir build && \
    cd build && \
    cmake -D CMAKE_BUILD_TYPE=Release \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D OPENCV_EXTRA_MODULES_PATH=/opt/opencv_contrib/modules \
    -D BUILD_EXAMPLES=ON .. && \
    make -j$(nproc) && \
    make install && \
    ldconfig

# 创建一个非root用户
ARG USERNAME=developer
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# 切换到非root用户
USER $USERNAME

# 拉取代码
WORKDIR /home/$USERNAME
RUN git clone --recursive https://github.com/FireWolves/mcerl.git

# 设置工作目录
WORKDIR /home/$USERNAME/mcerl

# 切换到最新分支
RUN git checkout dev/train

# 创建并激活virtualenv，安装依赖
RUN python3 -m venv .venv && \
    . .venv/bin/activate && \
    pip install -i https://mirror.zju.edu.cn/pypi/web/simple pip -U && \
    pip config set global.index-url https://mirror.zju.edu.cn/pypi/web/simple && \
    grep -v "git" requirements.txt > requirements_no_git.txt && \
    PIP_MAX_PARALLEL_DOWNLOADS=10 pip install --no-cache-dir -r requirements_no_git.txt --extra-index-url https://download.pytorch.org/whl/cu124 && \
    rm requirements_no_git.txt && \
    MAKEFLAGS="-j$(nproc)" pip install .

# 测试是否安装成功
RUN . .venv/bin/activate && python -c "from mcerl.env import Env" && \
    echo "Installation succeeded!"

# 入口命令
CMD ["/bin/bash"]
