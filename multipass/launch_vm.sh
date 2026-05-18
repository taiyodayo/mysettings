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
br0_mac="52:54:00:${mac_suffix:0:2}:${mac_suffix:2:2}:${mac_suffix:4:2}"

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
  --network "name=br0,mac=${br0_mac}" \
  --cloud-init "${rendered}"

multipass exec "${name}" -- bash -lc \
  'nohup sudo env DEBIAN_FRONTEND=noninteractive bash -lc "apt-get update && apt-get upgrade -y" >/tmp/apt-upgrade.log 2>&1 </dev/null &'

echo "Started background apt upgrade in ${name}; log: /tmp/apt-upgrade.log"
