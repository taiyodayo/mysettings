#!/bin/bash
# Script to customize Ubuntu SSH login message (MOTD)

echo "Customizing SSH login message..."

# Make a backup directory if it doesn't exist
sudo mkdir -p /etc/update-motd.d.bak

# 1. Disable ESM messages by creating the ubuntu-advantage config file
echo 'ENABLED=0' | sudo tee /etc/default/ubuntu-advantage
echo "Disabled ESM messages"

# 2. Remove documentation, management, and support links from header
if [ -f /etc/update-motd.d/00-header ]; then
  sudo cp /etc/update-motd.d/00-header /etc/update-motd.d.bak/
  sudo sed -i '/Documentation:/d' /etc/update-motd.d/00-header
  sudo sed -i '/Management:/d' /etc/update-motd.d/00-header
  sudo sed -i '/Support:/d' /etc/update-motd.d/00-header
  echo "Modified header to remove documentation links"
fi

# 3. Disable help text
if [ -f /etc/update-motd.d/10-help-text ]; then
  sudo chmod -x /etc/update-motd.d/10-help-text
  echo "Disabled help text"
fi

# 4. Clear and regenerate the MOTD cache
sudo rm -f /var/cache/motd-news
sudo run-parts /etc/update-motd.d/

echo "SSH login message has been customized. Log out and log back in to see the changes."
