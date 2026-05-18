#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
authorized_keys="${HOME}/.ssh/authorized_keys"

# Pick the host bridge for the VM's secondary NIC. Try br0 first (the
# usual name on these machines); if it's missing, list available bridges
# and prompt. Override the default with MULTIPASS_BRIDGE=<name>.
bridge="${MULTIPASS_BRIDGE:-br0}"
if ! ip link show "${bridge}" >/dev/null 2>&1; then
  echo "Host bridge '${bridge}' not found." >&2
  available="$(ip -br link show type bridge 2>/dev/null | awk '{print $1}')"
  if [[ -z "${available}" ]]; then
    echo "ERROR: no bridges on this host; create one before launching." >&2
    exit 1
  fi
  echo "Available bridges:" >&2
  printf '  %s\n' ${available} >&2
  read -rp "Which bridge to use? " bridge
  if [[ -z "${bridge}" ]] || ! ip link show "${bridge}" >/dev/null 2>&1; then
    echo "ERROR: bridge '${bridge}' not found." >&2
    exit 1
  fi
fi

# Pre-flight: the chosen bridge must let bridged DHCP through to the LAN.
# With net.bridge.bridge-nf-call-iptables=1 (Ubuntu default) every bridged
# frame is run through the iptables FORWARD chain. On hosts where Docker
# or UFW set FORWARD policy to DROP (typical), the VM's DHCP DISCOVER
# from its tap is silently dropped, ens4 never gets a lease, and the
# interface sits in `degraded (configuring)` forever.
if [[ -z "${MULTIPASS_SKIP_BR0_CHECK:-}" ]]; then
  nf_call=/proc/sys/net/bridge/bridge-nf-call-iptables
  if [[ -r "${nf_call}" && "$(cat "${nf_call}")" == "1" ]]; then
    cat >&2 <<EOF
ERROR: bridged DHCP on ${bridge} will be dropped by host iptables.

net.bridge.bridge-nf-call-iptables=1 sends bridged frames through the
iptables FORWARD chain. With Docker/UFW installed the chain's policy is
DROP, so the VM's DHCP traffic across ${bridge} never reaches the LAN
and ens4 stays in 'degraded (configuring)'.

Fix once on the host:

  ${script_dir}/setup_host_br0.sh

Re-run this script after applying. If you allowed FORWARD on ${bridge}
in some other way (e.g. explicit iptables ACCEPT rules), export
MULTIPASS_SKIP_BR0_CHECK=1 to bypass this check.
EOF
    exit 1
  fi
  unset nf_call
fi

if [[ ! -s "${authorized_keys}" ]]; then
  echo "No keys found at ${authorized_keys}" >&2
  exit 1
fi
keys_block="$(grep -v '^[[:space:]]*\(#\|$\)' "${authorized_keys}" | sed 's/^/      - /')"

name="${1:-}"
while [[ -z "${name}" ]]; do
  read -rp "Instance name: " name
done

if [[ -n "${TAIYO_PASSWORD_HASH:-}" ]]; then
  taiyo_password_hash="${TAIYO_PASSWORD_HASH}"
else
  if ! command -v openssl >/dev/null; then
    echo "openssl is required to hash the taiyo password" >&2
    exit 1
  fi

  while true; do
    read -rsp "New password for taiyo inside the VM: " taiyo_password
    echo
    read -rsp "Confirm new VM password for taiyo: " taiyo_password_confirm
    echo

    if [[ -z "${taiyo_password}" ]]; then
      echo "Password cannot be empty" >&2
    elif [[ "${taiyo_password}" == "${taiyo_password_confirm}" ]]; then
      break
    else
      echo "Passwords do not match" >&2
    fi
  done

  taiyo_password_hash="$(printf '%s' "${taiyo_password}" | openssl passwd -6 -stdin)"
  unset taiyo_password taiyo_password_confirm
fi

password_block="    lock_passwd: false
    passwd: '${taiyo_password_hash}'"

mac_suffix="$(printf '%s' "${name}" | sha256sum | cut -c1-6)"
bridge_mac="52:54:00:${mac_suffix:0:2}:${mac_suffix:2:2}:${mac_suffix:4:2}"

render_dir="${HOME}/snap/multipass/common/tmp"
mkdir -p "${render_dir}"
rendered="$(mktemp "${render_dir}/cloud-init.XXXXXX.yaml")"
chmod 0644 "${rendered}"
trap 'rm -f "${rendered}"' EXIT

awk -v block="${keys_block}" -v password_block="${password_block}" '
  /^__SSH_AUTHORIZED_KEYS__$/ { print block; next }
  /^__TAIYO_PASSWORD__$/ { if (password_block != "") print password_block; next }
  { print }
' "${script_dir}/bootstrap.yaml" > "${rendered}"

multipass launch 26.04 \
  --name "${name}" \
  --cpus $(( $(nproc) - 2 )) --memory 32G --disk 100G \
  --network "name=${bridge},mac=${bridge_mac}" \
  --cloud-init "${rendered}"

multipass exec "${name}" -- bash -lc \
  'nohup sudo env DEBIAN_FRONTEND=noninteractive bash -lc "apt-get update && apt-get upgrade -y" >/tmp/apt-upgrade.log 2>&1 </dev/null &'

echo "Started background apt upgrade in ${name}; log: /tmp/apt-upgrade.log"
