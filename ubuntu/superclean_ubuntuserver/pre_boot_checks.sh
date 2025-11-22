#!/bin/bash

# 1. Verify Kernel Modules
KERNEL_VER=$(uname -r)
if [ -d "/lib/modules/${KERNEL_VER}/kernel/net/netfilter" ]; then
    echo "✅ Kernel modules found."
else
    echo "❌ WARNING: Kernel modules missing! Reinstalling..."
    sudo apt install --reinstall "linux-image-${KERNEL_VER}" "linux-modules-${KERNEL_VER}" "linux-modules-extra-${KERNEL_VER}"
fi

# 2. Verify SSH is enabled
if systemctl is-enabled --quiet ssh; then
    echo "✅ SSH service is enabled."
else
    echo "❌ FIXING: SSH was disabled."
    sudo systemctl enable ssh
fi

# 3. Verify ZSH Shell exists
CURRENT_SHELL=$(grep "$USER" /etc/passwd | cut -d: -f7)
if [ -f "$CURRENT_SHELL" ]; then
    echo "✅ User shell exists."
else
    echo "❌ CRITICAL: Your shell is missing. Reverting to bash."
    sudo chsh -s /bin/bash "$USER"
fi

# 4. Verify Firewall (UFW) - THE FIXED LOGIC
# ^      = Start of line (The Port column)
# [[:space:]]* = Allow optional leading spaces
# (22|22/tcp|OpenSSH) = Match exact port 22, 22/tcp, or the "OpenSSH" app name
# \b     = Word boundary (Prevents matching 220, 2222)
IS_ACTIVE=$(sudo ufw status | grep -i "Status: active")

if [ -z "$IS_ACTIVE" ]; then
    echo "✅ Firewall is inactive (Safe)."
elif sudo ufw status | grep -qE "^[[:space:]]*(22|22/tcp|OpenSSH)\b"; then
    echo "✅ Firewall is active and ALLOWS SSH."
else
    echo "❌ DANGER: Firewall is ON but SSH (Port 22) is NOT strictly allowed."
    echo "   Run: sudo ufw allow ssh"
fi
