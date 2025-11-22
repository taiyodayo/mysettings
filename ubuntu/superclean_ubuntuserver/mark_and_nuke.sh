#!/bin/bash
set -euo pipefail
# -e: Exit immediately on error
# -u: Exit on undefined variables
# -o pipefail: Exit if any command in a pipe fails

BACKUP_FILE="$HOME/services_backup.txt"

echo "=== 1. SNAPSHOT SERVICE STATE ==="
# Save currently enabled services.
# We filter for 'enabled' explicitly to avoid grabbing 'static' or 'masked' services.
systemctl list-unit-files --state=enabled --no-legend | awk '{print $1}' > "$BACKUP_FILE"
echo "Backup saved to $BACKUP_FILE"

echo -e "\n=== 2. THE WHITELIST STRATEGY ==="
# Mark EVERYTHING as auto (disposable)
# We use xargs to prevent "Argument list too long" errors
apt-mark showmanual | xargs -r sudo apt-mark auto

# Define the "Do Not Kill" list
# Added 'software-properties-common' (add-apt-repository) and 'gnupg' (keys)
ESSENTIALS=(
    ubuntu-server linux-generic shim-signed grub-efi-amd64-signed efibootmgr
    sudo ca-certificates cron software-properties-common policykit-1 gnupg
    zsh zsh-common openssh-server
    netplan.io bridge-utils iproute2 dnsutils curl wget systemd-resolved
    docker.io docker-compose qemu-user-static
    wireguard zip unzip rsync tree ncdu tcpdump git htop vim nano tmux bash-completion
)

# Mark essentials as Manual (Keep)
echo "Marking essential packages..."
printf "%s\n" "${ESSENTIALS[@]}" | xargs -r sudo apt-mark manual

echo -e "\n=== 3. THE PURGE ==="
# This deletes everything NOT in the dependency tree of the list above
# sudo apt autoremove --purge -y --dry-run  # Use --dry-run for testing

# echo -e "\n=== 4. GHOST CLEANUP ==="
# # Cleans up 'rc' (config files of deleted packages)
# # xargs -r prevents running apt purge if grep finds nothing
# dpkg -l | grep "^rc" | awk '{print $2}' | xargs -r sudo apt purge -y

# echo -e "\n=== 5. RESTORE SERVICE STATE ==="
# if [ -s "$BACKUP_FILE" ]; then
#     echo "Restoring enabled services from backup..."
#     # xargs handles the list; systemctl enable creates the symlinks
#     xargs -a "$BACKUP_FILE" sudo systemctl enable || echo "Warning: Some services might not exist anymore, checking next..."
#     sudo systemctl daemon-reload
# else
#     echo "Warning: Backup file is empty. Skipping service restoration."
# fi

# echo "✅ Cleanup Complete."
