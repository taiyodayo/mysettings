#!/usr/bin/env bash
set -euo pipefail

has_gui() {
  if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
    return 0
  fi

  [ -S /tmp/.X11-unix/X0 ] || [ -S /tmp/.X11-unix/X1 ] && return 0

  if command -v systemctl >/dev/null 2>&1; then
    systemctl --quiet is-active graphical.target 2>/dev/null
  fi
}

if ! has_gui; then
  echo "No GUI environment detected. Skipping Ubuntu GUI tools."
  exit 0
fi

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This script requires apt."
  exit 1
fi

sudo apt-get update
sudo apt-get install -y fonts-firacode software-properties-common wget gpg

# Android-Studio
## Install Java JDK (if not already installed)
sudo apt-get install -y openjdk-11-jdk
## Add the Android Studio repository
sudo add-apt-repository -y ppa:maarten-fonville/android-studio
## Update package list
sudo apt-get update
## Install Android Studio
sudo apt-get install -y android-studio

if command -v brew >/dev/null 2>&1; then
  # fvm / flutter
  brew tap leoafarias/fvm
  brew install fvm
  fvm install stable
  fvm global stable
else
  echo "brew not found. Skipping fvm/flutter install."
fi

# Google Chrome
sudo wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmour -o /usr/share/keyrings/google-chrome-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt-get update
sudo apt-get install -y google-chrome-stable
