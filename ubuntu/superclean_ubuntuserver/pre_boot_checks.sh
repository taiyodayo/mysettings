#!/bin/bash
set -euo pipefail

echo "=== PRE-REBOOT SAFETY AUDIT ==="
FAILURES=0

# 1. KERNEL MODULE CHECK
# Ensures the kernel on disk matches the running kernel.
KERNEL_VER=$(uname -r)
MODULE_DIR="/lib/modules/${KERNEL_VER}/kernel/net/netfilter"

if [ -d "$MODULE_DIR" ]; then
    echo "✅ [KERNEL]  Modules found for ${KERNEL_VER}."
else
    echo "❌ [KERNEL]  CRITICAL: Modules missing for ${KERNEL_VER}."
    echo "   FIX: sudo apt install --reinstall linux-image-${KERNEL_VER} linux-modules-${KERNEL_VER} linux-modules-extra-${KERNEL_VER}"
    FAILURES=$((FAILURES+1))
fi

# 2. SSH SERVICE CHECK
# Checks if systemd thinks SSH is enabled.
if systemctl is-enabled --quiet ssh; then
    echo "✅ [SSH]     Service is ENABLED."
else
    echo "❌ [SSH]     Service is DISABLED."
    echo "   FIX: sudo systemctl enable ssh"
    FAILURES=$((FAILURES+1))
fi

# 3. SHELL CHECK
# Verifies the user's shell binary actually exists.
CURRENT_SHELL=$(grep "^$USER:" /etc/passwd | cut -d: -f7)
if [ -x "$CURRENT_SHELL" ]; then
    echo "✅ [SHELL]   Shell ($CURRENT_SHELL) exists and is executable."
else
    echo "❌ [SHELL]   Shell ($CURRENT_SHELL) is MISSING."
    echo "   FIX: sudo chsh -s /bin/bash $USER"
    FAILURES=$((FAILURES+1))
fi

# 4. FIREWALL (UFW) CHECK - STRICT REGEX
# Looks for "Status: active"
UFW_STATUS=$(sudo ufw status | grep -i "Status: active" || true)

if [ -z "$UFW_STATUS" ]; then
    echo "✅ [UFW]     Firewall is INACTIVE (Safe for reboot)."
else
    # RIGOROUS REGEX EXPLANATION:
    # ^\s* = Start of line, optional whitespace
    # (22|...ssh)   = Match specific port 22 OR 'OpenSSH' literal
    # (/tcp)?       = Optional /tcp suffix
    # \s+           = MUST be followed by whitespace (Prevents 22 matching 220)
    # .* = Any characters in between
    # ALLOW         = The word ALLOW (Case insensitive usually, but UFW prints caps)
    if sudo ufw status | grep -Eq "^\s*(22(/tcp)?|OpenSSH)\s+.*ALLOW"; then
        echo "✅ [UFW]     Firewall is ACTIVE and SSH is explicitly ALLOWED."
    else
        echo "❌ [UFW]     DANGER: Firewall is ON but SSH (Port 22) rule is missing!"
        echo "   FIX: sudo ufw allow ssh"
        FAILURES=$((FAILURES+1))
    fi
fi

echo "--------------------------------"
if [ "$FAILURES" -eq 0 ]; then
    echo "🚀 ALL SYSTEMS GO. SAFE TO REBOOT."
else
    echo "🛑 DO NOT REBOOT. FIX $FAILURES ERRORS ABOVE."
fi