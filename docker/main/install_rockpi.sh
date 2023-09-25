#!/bin/bash

set -euxo pipefail

apt-get -qq update

apt-get -qq install --no-install-recommends -y \
    apt-transport-https \
    autoconf \
    automake \
    build-essential \
    cmake \
    coreutils \
    curl \
    doxygen \
    git-core \
    graphviz \
    gnupg \
    imagemagick \
    libaom-dev \
    libasound2-dev \
    libass-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavfilter-dev \
    libavformat-dev \
    libavutil-dev \
    libdav1d-dev \
    libdrm-dev \
    libfreetype6-dev \
    libgmp-dev \
    libgnutls28-dev \
    libmp3lame-dev \
    libopencore-amrnb-dev \
    libopencore-amrwb-dev \
    libopus-dev \
    librtmp-dev  \
    libsdl2-dev \
    libsdl2-image-dev\
    libsdl2-mixer-dev \
    libsdl2-net-dev \
    libsdl2-ttf-dev \
    libsnappy-dev \
    libsoxr-dev \
    libssh-dev \
    libssl-dev \
    libtool \
    libv4l-dev \
    libva-dev \
    libvdpau-dev \
    libvorbis-dev \
    libvo-amrwbenc-dev \
    libx264-dev \
    libx265-dev \
    libxcb1-dev \
    libxcb-shape0-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    libxcb1-dev \
    libxml2-dev \
    libwebp-dev \
    libyuv-dev \
    locales \
    lzma-dev \
    meson \
    nasm \
    ninja-build \
    pkg-config \
    procps \
    software-properties-common \
    texinfo \
    unzip \
    vainfo \
    wget \
    xz-utils \
    yasm \
    zlib1g-dev
    # python3-dev \
    # python3-pip \
    

add-apt-repository -y ppa:liujianfeng1994/panfork-mesa
add-apt-repository -y ppa:liujianfeng1994/rockchip-multimedia

apt-get -qq update

#Install libdri2to3 and libgl4es
apt install -y libdri2to3 \
    libgl4es \
    libgl4es-dev \
    librga-dev


# install mpp and custom FFmpeg

if [ -e /usr/local/include/mpp/mpp.h ] || [ -e /usr/include/mpp/mpp.h ] || pkg-config --exists rockchip-mpp; then
    HAS_MPP=1
else
# Install mpp from sources

# Install libmali, librga, and mpp from orangepi repo
# Get prereqs for FFMPeg
cd /tmp
git clone https://github.com/orangepi-xunlong/rk-rootfs-build.git
cd rk-rootfs-build
git checkout rk3588_packages_jammy
git pull
apt-get install -y --allow-downgrades /tmp/rk-rootfs-build/rga2/librga*jammy_arm64.deb \
    /tmp/rk-rootfs-build/mpp/librockchip-mpp*.deb \
    /tmp/rk-rootfs-build/mesa/mali-g610-firmware*.deb \
    # /tmp/rk-rootfs-build/ffmpeg/libav*5*.deb \
    # /tmp/rk-rootfs-build/ffmpeg/libav*7*.deb \
    # /tmp/rk-rootfs-build/ffmpeg/libpostproc5*.deb \
    # /tmp/rk-rootfs-build/ffmpeg/libsw*3*.deb \
    # /tmp/rk-rootfs-build/ffmpeg/libsw*5*.deb
    # /tmp/rk-rootfs-build/ffmpeg/*.deb
# TODO: Figure out if this package is necessary after installing the g610 firmware
apt install -y -o Dpkg::Options::="--force-overwrite" /tmp/rk-rootfs-build/libmali/libmali-valhall-g610-g6p0-x11_1*.deb

# bash -c 'echo "/usr/lib/libmali.so" > /etc/OpenCL/vendors/mali.icd'
cd /tmp
rm -rf rk-rootfs-build

# cd /tmp
# git clone https://github.com/rockchip-linux/mpp.git
# cd mpp
# mkdir build || true && cd build

# ARCH=$(uname -m)
# EXTRA_CFLAGS=""
# EXTRA_CXXFLAGS=""

# if [ "$ARCH" = "aarch64" ]; then
#     EXTRA_CFLAGS="-march=armv8-a+crc"
#     EXTRA_CXXFLAGS="-march=armv8-a+crc"
# fi

# cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_C_FLAGS="${EXTRA_CFLAGS}" -DCMAKE_CXX_FLAGS="${EXTRA_CXXFLAGS}" ../
# make -j$(nproc)
# make install
# ldconfig

fi


# Install custom ffmpeg
if command -v ffmpeg >/dev/null 2>&1; then
    HAS_FFMPEG=1
else
    HAS_FFMPEG=0
fi

# Compile ffmpeg

cd /tmp
git clone https://github.com/hbiyik/FFmpeg.git
cd FFmpeg

ARCH=$(uname -m)
EXTRA_CFLAGS="-I/usr/local/include"
EXTRA_LDFLAGS="-L/usr/local/lib"

if [ "$ARCH" = "aarch64" ]; then
    EXTRA_CFLAGS="${EXTRA_CFLAGS} -march=armv8-a+crc"
fi

PKG_CONFIG_PATH="/usr/local/lib/pkgconfig" ./configure \
    --enable-rkmpp \
    --extra-cflags="${EXTRA_CFLAGS}" \
    --extra-ldflags="${EXTRA_LDFLAGS}" \
    --extra-libs="-lpthread -lm -latomic" \
    --arch=arm64 \
    --enable-gmp \
    --enable-gpl \
    --enable-libaom \
    --enable-libass \
    --enable-libdav1d \
    --enable-libdrm \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libopencore-amrnb \
    --enable-libopencore-amrwb \
    --enable-libopus \
    --enable-librtmp \
    --enable-libsnappy \
    --enable-libsoxr \
    --enable-libssh \
    --enable-libvorbis \
    --enable-libwebp \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libxml2 \
    --enable-nonfree \
    --enable-version3 \
    --target-os=linux \
    --enable-pthreads \
    --enable-openssl 
make -j$(nproc)

if [[ "${HAS_FFMPEG}" == 1 ]]; then
# To avoid possible race condition.
    apt -y remove ffmpeg
fi

make install
ldconfig

# create ln for ffmpeg and ffprobe from btbn to custom rk supported version in /usr/bin
mkdir -p /usr/lib/btbn-ffmpeg/bin
cd /usr/lib/btbn-ffmpeg/bin
ln -s /usr/bin/ffmpeg
ln -s /usr/bin/ffprobe

cd /tmp
rm -rf mpp
rm -rf FFmpeg

# create ln for ffmpeg and ffprobe from btbn to custom rk supported version in /usr/bin
cd /usr/lib/btbn-ffmpeg/bin
rm ffmpeg
rm ffprobe
ln -s /usr/bin/ffmpeg
ln -s /usr/bin/ffprobe

apt-get purge gnupg apt-transport-https xz-utils software-properties-common -y
apt-get clean autoclean -y
apt-get autoremove --purge -y
rm -rf /var/lib/apt/lists