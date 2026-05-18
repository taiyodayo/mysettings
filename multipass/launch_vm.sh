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

rendered="$(mktemp --suffix=.yaml)"
trap 'rm -f "${rendered}"' EXIT

awk -v block="${keys_block}" '
  /^__SSH_AUTHORIZED_KEYS__$/ { print block; next }
  { print }
' "${script_dir}/bootstrap.yaml" > "${rendered}"

multipass launch 26.04 \
  --name "${name}" \
  --cpus $(( $(nproc) - 2 )) --memory 32G --disk 100G \
  --cloud-init "${rendered}"
