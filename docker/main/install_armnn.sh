#!/bin/bash

set -euxo pipefail

apt-get -qq update

apt-get -qq install --no-install-recommends -y \
    apt-transport-https \
    gnupg \
    wget \
    procps vainfo \
    unzip locales libxml2 xz-utils \
    software-properties-common \
    curl \
    jq \
    nethogs \
    git

add-apt-repository -y ppa:armnn/ppa

apt-get -qq update

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
    python3-pyarmnn

    

apt-get purge gnupg apt-transport-https xz-utils software-properties-common -y
apt-get clean autoclean -y
apt-get autoremove --purge -y
rm -rf /var/lib/apt/lists/*