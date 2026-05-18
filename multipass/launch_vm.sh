#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
authorized_keys="${HOME}/.ssh/authorized_keys"

if [[ ! -s "${authorized_keys}" ]]; then
  echo "No keys found at ${authorized_keys}" >&2
  exit 1
fi
keys_block="$(grep -v '^[[:space:]]*\(#\|$\)' "${authorized_keys}" | sed 's/^/      - /')"

name="${1:-}"
while [[ -z "${name}" ]]; do
  read -rp "Instance name: " name
done

mac_suffix="$(printf '%s' "${name}" | sha256sum | cut -c1-6)"
br0_mac="52:54:00:${mac_suffix:0:2}:${mac_suffix:2:2}:${mac_suffix:4:2}"

render_dir="${HOME}/snap/multipass/common/tmp"
mkdir -p "${render_dir}"
rendered="$(mktemp "${render_dir}/cloud-init.XXXXXX.yaml")"
chmod 0644 "${rendered}"
trap 'rm -f "${rendered}"' EXIT

awk -v block="${keys_block}" -v br0_mac="${br0_mac}" '
  /^__SSH_AUTHORIZED_KEYS__$/ { print block; next }
  { gsub(/__BR0_MAC__/, br0_mac) }
  { print }
' "${script_dir}/bootstrap.yaml" > "${rendered}"

multipass launch 26.04 \
  --name "${name}" \
  --cpus $(( $(nproc) - 2 )) --memory 32G --disk 100G \
  --network "name=br0,mac=${br0_mac}" \
  --cloud-init "${rendered}"
