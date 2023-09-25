# syntax=docker/dockerfile:1.4

# https://askubuntu.com/questions/972516/debian-frontend-environment-variable
ARG DEBIAN_FRONTEND=noninteractive

ARG BASE_IMAGE=ubuntu:jammy
ARG SLIM_BASE=ubuntu:jammy

FROM ${BASE_IMAGE} AS base

FROM --platform=${BUILDPLATFORM} ubuntu:jammy AS base_host

FROM ${SLIM_BASE} AS slim-base

# update mirror
RUN apt update && \
    apt install -y ca-certificates && \
    sed -i 's/http:\/\/ports.ubuntu.com\/ubuntu-ports\//https:\/\/mirror.kumi.systems\/ubuntu-ports\//g' /etc/apt/sources.list && \
    apt update

FROM base AS wget
ARG DEBIAN_FRONTEND
RUN apt-get update \
    && apt-get install -y wget xz-utils \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /rootfs

FROM base AS nginx
ARG DEBIAN_FRONTEND
ENV CCACHE_DIR /root/.ccache
ENV CCACHE_MAXSIZE 2G

# bind /var/cache/apt to tmpfs to speed up nginx build
RUN --mount=type=tmpfs,target=/tmp --mount=type=tmpfs,target=/var/cache/apt \
    --mount=type=bind,source=docker/main/build_nginx.sh,target=/deps/build_nginx.sh \
    --mount=type=cache,target=/root/.ccache \
    /deps/build_nginx.sh

FROM scratch AS go2rtc
ARG TARGETARCH
WORKDIR /rootfs/usr/local/go2rtc/bin
ADD --link --chmod=755 "https://github.com/AlexxIT/go2rtc/releases/download/v1.6.2/go2rtc_linux_${TARGETARCH}" go2rtc



FROM wget AS models

# Get model and labels
RUN wget -qO edgetpu_model.tflite https://github.com/google-coral/test_data/raw/release-frogfish/ssdlite_mobiledet_coco_qat_postprocess_edgetpu.tflite
RUN wget -qO cpu_model.tflite https://github.com/google-coral/test_data/raw/release-frogfish/ssdlite_mobiledet_coco_qat_postprocess.tflite
RUN mkdir -p ./usr/lib && \
    wget -qO ./usr/lib/librknnrt.so https://github.com/rockchip-linux/rknpu2/raw/master/runtime/RK3588/Linux/librknn_api/aarch64/librknnrt.so


COPY labelmap.txt .
# yolov5 RKNN model converted from tflite
COPY yolov5s_f16.rknn .
COPY yolov5s-640-640.rknn .
COPY yolov5s_LubanCat.rknn .
COPY ssd_mobilenet_v1_coco.rknn .

# Get Audio Model and labels
RUN wget -qO cpu_audio_model.tflite https://tfhub.dev/google/lite-model/yamnet/classification/tflite/1?lite-format=tflite
COPY audio-labelmap.txt .


FROM wget AS s6-overlay
ARG TARGETARCH
RUN --mount=type=bind,source=docker/main/install_s6_overlay.sh,target=/deps/install_s6_overlay.sh \
    /deps/install_s6_overlay.sh


FROM base AS wheels
ARG DEBIAN_FRONTEND
ARG TARGETARCH
ARG TZ=America/Mexico_City

# Use a separate container to build wheels to prevent build dependencies in final image
RUN apt-get -qq update \
    && apt-get -qq install -y \
    software-properties-common \
    apt-transport-https \
    gnupg \
    wget \
    && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 648ACFD622F3D138 \
    && echo "deb http://deb.debian.org/debian bullseye main contrib non-free" | tee /etc/apt/sources.list.d/raspi.list \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get -qq update \
    && apt-get -qq install -y \
    python3.9 \
    python3.9-dev \
    python3.9-distutils \
    wget \
    # opencv dependencies
    build-essential cmake git pkg-config libgtk-3-dev \
    libavcodec-dev libavformat-dev libswscale-dev libv4l-dev \
    libxvidcore-dev libx264-dev libjpeg-dev libpng-dev libtiff-dev \
    gfortran openexr libatlas-base-dev libssl-dev\
    libtbb2 libtbb-dev libdc1394-dev libopenexr-dev \
    libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev \
    # scipy dependencies
    gcc gfortran libopenblas-dev liblapack-dev software-properties-common && \
    rm -rf /var/lib/apt/lists/*
# Ensure python3 defaults to python3.9
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1

RUN wget -q https://bootstrap.pypa.io/get-pip.py -O get-pip.py \
    && python3.9 get-pip.py "pip"

COPY docker/main/requirements.txt /requirements.txt
RUN pip3 install -r /requirements.txt

COPY docker/main/requirements-wheels.txt /requirements-wheels.txt
RUN pip3 wheel --wheel-dir=/wheels -r /requirements-wheels.txt

# ArmNN
FROM wget AS armnn

ADD https://github.com/ARM-software/armnn/releases/download/v23.08/ArmNN-linux-aarch64.tar.gz .
RUN mkdir -p /rootfs/usr/lib/ArmNN-linux-aarch64 && \
    tar xfvz ./ArmNN-linux-aarch64.tar.gz -C /rootfs/usr/lib/ArmNN-linux-aarch64 && \
    rm ./ArmNN-linux-aarch64.tar.gz

RUN --mount=type=bind,source=docker/main/install_armnn.sh,target=/deps/install_armnn.sh \
    /deps/install_armnn.sh

# Collect deps in a single layer
FROM scratch AS deps-rootfs
COPY --from=nginx /usr/local/nginx/ /usr/local/nginx/
COPY --from=go2rtc /rootfs/ /
COPY --from=s6-overlay /rootfs/ /
COPY --from=models /rootfs/ /
COPY docker/main/rootfs/ /
COPY --from=armnn /rootfs/ /
COPY --from=rockpi /rootfs/ /


# Frigate deps (ffmpeg, python, nginx, go2rtc, s6-overlay, etc)
FROM base AS deps
ARG TARGETARCH

ARG DEBIAN_FRONTEND
# http://stackoverflow.com/questions/48162574/ddg#49462622
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn

# https://github.com/NVIDIA/nvidia-docker/wiki/Installation-(Native-GPU-Support)
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES="compute,video,utility"

ENV PATH="/usr/lib/btbn-ffmpeg/bin:/usr/local/go2rtc/bin:/usr/local/nginx/sbin:${PATH}"

# Install dependencies
RUN --mount=type=bind,source=docker/main/install_deps.sh,target=/deps/install_deps.sh \
    /deps/install_deps.sh

RUN --mount=type=bind,from=wheels,source=/wheels,target=/deps/wheels \
    python3 -m pip install --upgrade pip && \
    pip3 install -U /deps/wheels/*.whl

COPY --from=deps-rootfs / /

RUN ldconfig

EXPOSE 5000
EXPOSE 1935
EXPOSE 8554
EXPOSE 8555/tcp 8555/udp

# Configure logging to prepend timestamps, log to stdout, keep 0 archives and rotate on 10MB
ENV S6_LOGGING_SCRIPT="T 1 n0 s10000000 T"
ENV LD_LIBRARY_PATH="/usr/lib/ArmNN-linux-aarch64:${LD_LIBRARY_PATH}"

ENTRYPOINT ["/init"]
CMD []

# RockPi Requirements
FROM base AS rockpi
RUN mkdir -p /rootfs/usr/lib/rockpi
RUN --mount=type=bind,source=docker/main/install_rockpi.sh,target=/deps/install_rockpi.sh \
    /deps/install_rockpi.sh

# Frigate deps with Node.js and NPM for devcontainer
FROM deps AS devcontainer

# Do not start the actual Frigate service on devcontainer as it will be started by VSCode
# But start a fake service for simulating the logs
COPY docker/main/fake_frigate_run /etc/s6-overlay/s6-rc.d/frigate/run

# Create symbolic link to the frigate source code, as go2rtc's create_config.sh uses it
RUN mkdir -p /opt/frigate \
    && ln -svf /workspace/frigate/frigate /opt/frigate/frigate

# Install Node 16
RUN apt-get update \
    && apt-get install wget -y \
    && wget -qO- https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g npm@9

WORKDIR /workspace/frigate

RUN apt-get update \
    && apt-get install make -y \
    && rm -rf /var/lib/apt/lists/*

RUN --mount=type=bind,source=./docker/main/requirements-dev.txt,target=/workspace/frigate/requirements-dev.txt \
    pip3 install -r requirements-dev.txt

CMD ["sleep", "infinity"]


# Frigate web build
# This should be architecture agnostic, so speed up the build on multiarch by not using QEMU.
FROM --platform=$BUILDPLATFORM node:16 AS web-build

WORKDIR /work
COPY web/package.json web/package-lock.json ./
RUN npm install

COPY web/ ./
RUN npm run build \
    && mv dist/BASE_PATH/monacoeditorwork/* dist/assets/ \
    && rm -rf dist/BASE_PATH

# Collect final files in a single layer
FROM scratch AS rootfs

WORKDIR /opt/frigate/
COPY frigate frigate/
COPY migrations migrations/
COPY --from=web-build /work/dist/ web/

# Frigate final container
FROM deps AS frigate

WORKDIR /opt/frigate/
COPY --from=rootfs / /