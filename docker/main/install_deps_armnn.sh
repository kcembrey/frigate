#!/bin/bash

set -euxo pipefail

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
    python3-pyarmnn \

apt-get purge gnupg apt-transport-https xz-utils -y
apt-get clean autoclean -y
apt-get autoremove --purge -y
rm -rf /var/lib/apt/lists/*