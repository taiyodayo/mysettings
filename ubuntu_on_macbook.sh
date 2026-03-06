#!/bin/bash
# Post-install survival script for MacBook10,1 on Ubuntu 25.10

# 1. Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo: sudo ./macbook_setup.sh"
  exit 1
fi

echo "=== Fixing the SPI Keyboard & Trackpad ==="
# Check if the modules are already added to avoid duplicating lines
if ! grep -q "applespi" /etc/initramfs-tools/modules; then
  echo "Adding SPI modules to initramfs..."
  echo -e "\napplespi\nintel_lpss_pci\nspi_pxa2xx_platform\nspi_pxa2xx_pci" >> /etc/initramfs-tools/modules
  
  echo "Updating initramfs (this will take a moment)..."
  update-initramfs -u
  echo "Initramfs updated successfully."
else
  echo "SPI modules are already in your initramfs config. Skipping."
fi

echo ""
echo "=== Installing Patched Audio Driver (x5444 fork) ==="
# Ensure git is installed
if ! command -v git &> /dev/null; then
  echo "Git is not installed. Installing git now..."
  apt-get update && apt-get install -y git
fi

# Clone the repository to the /tmp directory
cd /tmp || exit
if [ -d "macbook12-audio-driver" ]; then
  echo "Removing old clone of the audio driver..."
  rm -rf macbook12-audio-driver
fi

echo "Cloning the audio driver repository..."
git clone https://github.com/x5444/macbook12-audio-driver
cd macbook12-audio-driver || exit

echo "Running the audio driver installation script..."
chmod +x install.sh
./install.sh

echo ""
echo "=== Setup Complete! ==="
echo "Please unplug any external keyboards/mice and reboot your MacBook."
