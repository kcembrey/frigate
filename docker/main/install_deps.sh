#!/bin/bash

set -euxo pipefail

apt-get -qq update

apt-get -qq install --no-install-recommends -y \
    apt-transport-https \
    gnupg \
    wget \
    procps vainfo \
    unzip locales tzdata libxml2 xz-utils \
    software-properties-common \
    curl \
    jq \
    nethogs \
    git

add-apt-repository -y ppa:liujianfeng1994/panfork-mesa
add-apt-repository -y ppa:liujianfeng1994/rockchip-multimedia
add-apt-repository -y ppa:armnn/ppa

apt update

# Install ArmNN
apt install -y armnn-latest-all \
    armnn-latest-cpu-gpu-ref \
    armnn-latest-cpu-gpu \
    armnn-latest-cpu \
    armnn-latest-gpu \
    armnn-latest-ref \
    libarmnn-cpuacc-backend32 \
    libarmnn-cpuref-backend32 \
    libarmnn-gpuacc-backend32 \
    libarmnn22 \
    libarmnn32 \
    libarmnnaclcommon22 \
    libarmnnaclcommon32 \
    libarmnntfliteparser24 \
    python3-pyarmnn \
    libyuv-dev \
    librga-dev

    

# Install python 3.9
add-apt-repository -y ppa:deadsnakes/ppa
apt install -y python3.9 python3.9-dev python3.9-distutils python3-pip
rm -f /usr/bin/python3
ln -s /usr/bin/python3.9 /usr/bin/python3

# ensure python3 defaults to python3.9
update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1

mkdir -p -m 600 /root/.gnupg

# add coral repo
curl -fsSLo - https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
    gpg --dearmor -o /etc/apt/trusted.gpg.d/google-cloud-packages-archive-keyring.gpg
echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | tee /etc/apt/sources.list.d/coral-edgetpu.list
echo "libedgetpu1-max libedgetpu/accepted-eula select true" | debconf-set-selections

# enable non-free repo in Debian
if grep -q "Debian" /etc/issue; then
    sed -i -e's/ main/ main contrib non-free/g' /etc/apt/sources.list
fi

# coral drivers
apt-get -qq update
apt-get -qq install --no-install-recommends --no-install-suggests -y \
    libedgetpu1-max

# btbn-ffmpeg -> amd64
if [[ "${TARGETARCH}" == "amd64" ]]; then
    mkdir -p /usr/lib/btbn-ffmpeg
    wget -qO btbn-ffmpeg.tar.xz "https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2022-07-31-12-37/ffmpeg-n5.1-2-g915ef932a3-linux64-gpl-5.1.tar.xz"
    tar -xf btbn-ffmpeg.tar.xz -C /usr/lib/btbn-ffmpeg --strip-components 1
    rm -rf btbn-ffmpeg.tar.xz /usr/lib/btbn-ffmpeg/doc /usr/lib/btbn-ffmpeg/bin/ffplay
fi

# ffmpeg -> arm64
if [[ "${TARGETARCH}" == "arm64" ]]; then
    mkdir -p /usr/lib/btbn-ffmpeg
    wget -qO btbn-ffmpeg.tar.xz "https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2022-07-31-12-37/ffmpeg-n5.1-2-g915ef932a3-linuxarm64-gpl-5.1.tar.xz"
    tar -xf btbn-ffmpeg.tar.xz -C /usr/lib/btbn-ffmpeg --strip-components 1
    rm -rf btbn-ffmpeg.tar.xz /usr/lib/btbn-ffmpeg/doc /usr/lib/btbn-ffmpeg/bin/ffplay
fi

# arch specific packages
if [[ "${TARGETARCH}" == "amd64" ]]; then
    # Use debian testing repo only for hwaccel packages
    echo 'deb http://deb.debian.org/debian testing main non-free' >/etc/apt/sources.list.d/debian-testing.list
    apt-get -qq update
    # intel-opencl-icd specifically for GPU support in OpenVino
    apt-get -qq install --no-install-recommends --no-install-suggests -y \
        intel-opencl-icd \
        mesa-va-drivers libva-drm2 intel-media-va-driver-non-free i965-va-driver libmfx1 radeontop intel-gpu-tools
    # something about this dependency requires it to be installed in a separate call rather than in the line above
    apt-get -qq install --no-install-recommends --no-install-suggests -y \
        i965-va-driver-shaders
    rm -f /etc/apt/sources.list.d/debian-testing.list
fi

if [[ "${TARGETARCH}" == "arm64" ]]; then
    apt-get -qq install --no-install-recommends --no-install-suggests -y \
        libva-drm2 mesa-va-drivers
fi

# install mpp and custom FFmpeg

set -euxo pipefail

apt-get -qq update
apt install -y pkg-config

if [ -e /usr/local/include/mpp/mpp.h ] || [ -e /usr/include/mpp/mpp.h ] || pkg-config --exists rockchip-mpp; then
    HAS_MPP=1
else
# Install mpp from sources
apt-get -qq update
# TODO: move all apt-get installs to dedicated script for having it in a single Docker layer = performance of reruns.
apt-get install -y git build-essential yasm pkg-config \
    libtool coreutils autoconf automake build-essential cmake \
    doxygen git graphviz imagemagick libasound2-dev libass-dev \
    libavcodec-dev libavdevice-dev libavfilter-dev libavformat-dev \
    libavutil-dev libfreetype6-dev libgmp-dev libmp3lame-dev \
    libopencore-amrnb-dev libopencore-amrwb-dev libopus-dev \
    librtmp-dev libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev \
    libsdl2-net-dev libsdl2-ttf-dev libsnappy-dev libsoxr-dev \
    libssh-dev libssl-dev libtool libv4l-dev libva-dev libvdpau-dev \
    libvo-amrwbenc-dev libvorbis-dev libwebp-dev libx264-dev libx265-dev \
    libxcb-shape0-dev libxcb-shm0-dev libxcb-xfixes0-dev libxcb1-dev \
    libxml2-dev lzma-dev meson nasm pkg-config python3-dev \
    python3-pip texinfo wget yasm zlib1g-dev libdrm-dev libaom-dev libdav1d-dev \
    libmp3lame-dev

cd /tmp
git clone https://github.com/rockchip-linux/mpp.git
cd mpp
mkdir build || true && cd build

ARCH=$(uname -m)
EXTRA_CFLAGS=""
EXTRA_CXXFLAGS=""

if [ "$ARCH" = "aarch64" ]; then
    EXTRA_CFLAGS="-march=armv8-a+crc"
    EXTRA_CXXFLAGS="-march=armv8-a+crc"
fi

cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_C_FLAGS="${EXTRA_CFLAGS}" -DCMAKE_CXX_FLAGS="${EXTRA_CXXFLAGS}" ../
make -j$(nproc)
make install
ldconfig

fi

# TODO: consider moving ffmpeg compillation to a dedicated ffmpeg.sh script
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
rm -rf /var/lib/apt/lists/*

# Install yq, for frigate-prepare and go2rtc echo source
curl -fsSL \
    "https://github.com/mikefarah/yq/releases/download/v4.33.3/yq_linux_$(dpkg --print-architecture)" \
    --output /usr/local/bin/yq
chmod +x /usr/local/bin/yq
