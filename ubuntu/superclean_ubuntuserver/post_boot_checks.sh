#!/usr/bin/env bash
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root."
  exit 1
fi

sudo systemctl status docker --no-pager
sudo docker run --rm hello-world
