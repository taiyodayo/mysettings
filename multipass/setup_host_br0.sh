#!/usr/bin/env bash
# One-time host-side fix so the VM's DHCP on br0 isn't dropped by iptables.
#
# Ubuntu defaults net.bridge.bridge-nf-call-iptables=1, which routes every
# bridged frame through the host iptables FORWARD chain. On hosts running
# Docker or UFW the chain's policy is DROP, so a VM's DHCP DISCOVER from
# its tap on br0 never reaches the LAN and ens4 stays in
# `degraded (configuring)` forever.
#
# This drops a sysctl file flipping both bridge-nf-call-{ip,ip6}tables to 0
# and reloads. Bridged-only frames (tap <-> enp5s0 on br0) now bypass
# iptables; routed traffic (Docker NAT, host stack) is unaffected.
#
# Run once per host:
#   ./multipass/setup_host_br0.sh

set -euo pipefail

conf=/etc/sysctl.d/99-br0-bridge-nf.conf

sudo tee "${conf}" >/dev/null <<'EOF'
net.bridge.bridge-nf-call-iptables = 0
net.bridge.bridge-nf-call-ip6tables = 0
EOF

sudo sysctl --system

echo
echo "Wrote ${conf} and reloaded sysctl."
echo "If a VM is already running with ens4 stuck, force a re-DHCP:"
echo "  multipass exec <name> -- sudo networkctl reconfigure ens4"
