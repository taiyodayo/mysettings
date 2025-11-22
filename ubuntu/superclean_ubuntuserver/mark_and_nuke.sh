#!/bin/bash

# --- STEP 1: SNAPSHOT SERVICE STATE ---
echo "Backing up enabled services..."
# Using xargs compatible format just in case, though simple redirection is fine here
systemctl list-unit-files --state=enabled --no-legend | awk '{print $1}' > ~/services_backup.txt

# --- STEP 2: THE WHITELIST STRATEGY ---
# Mark EVERYTHING as disposable using xargs (Fixes SC2046)
apt-mark showmanual | xargs sudo apt-mark auto

# Immediately rescue the Essentials
# We use a bash array for cleaner reading and quoting
ESSENTIALS=(
    ubuntu-server linux-generic shim-signed grub-efi-amd64-signed efibootmgr
    sudo ca-certificates cron software-properties-common policykit-1
    zsh zsh-common openssh-server
    netplan.io bridge-utils iproute2 dnsutils curl wget systemd-resolved
    docker.io docker-compose qemu-user-static
    wireguard zip unzip rsync tree ncdu tcpdump git htop vim nano tmux bash-completion
)

# Expand the array safely
sudo apt-mark manual "${ESSENTIALS[@]}"

# --- STEP 3: THE PURGE ---
echo "Starting the purge..."
sudo apt autoremove --purge -y

# --- STEP 4: GHOST CLEANUP ---
# Remove 'rc' config files (using xargs -r to only run if input exists)
dpkg -l | grep "^rc" | awk '{print $2}' | xargs -r sudo apt purge -y

# --- STEP 5: RESTORE SERVICE STATE ---
echo "Restoring service states..."
# Check if file exists and is not empty before restoring
if [ -s ~/services_backup.txt ]; then
    xargs -a ~/services_backup.txt sudo systemctl enable
    sudo systemctl daemon-reload
fi

echo "Cleanup Complete. Proceed to Verification."
