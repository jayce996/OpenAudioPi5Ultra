#!/bin/bash
set -euo pipefail

if [ ! -d ./pi-gen ]; then
  git clone --depth=1 https://github.com/RPi-Distro/pi-gen.git ./pi-gen
fi

cp -v pi-gen-config/config ./pi-gen/config
rsync -av pi-gen-custom/ ./pi-gen/

cd pi-gen
sudo ./build-docker.sh
echo "Done. Check ./deploy/ for the .img"
