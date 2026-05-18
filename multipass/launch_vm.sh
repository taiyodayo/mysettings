#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/multipass-launch"
cache_file="${cache_dir}/github_user"
mkdir -p "${cache_dir}"

if [[ -s "${cache_file}" ]]; then
  gh_user="$(cat "${cache_file}")"
else
  default_user="$(gh api user --jq .login 2>/dev/null || true)"
  if [[ -n "${default_user}" ]]; then
    read -rp "GitHub username [${default_user}]: " gh_user
    gh_user="${gh_user:-${default_user}}"
  else
    gh_user=""
    while [[ -z "${gh_user}" ]]; do
      read -rp "GitHub username: " gh_user
    done
  fi
  printf '%s\n' "${gh_user}" > "${cache_file}"
fi

keys_url="https://github.com/${gh_user}.keys"
keys="$(curl -fsSL "${keys_url}" || true)"
if [[ -z "${keys}" ]]; then
  echo "No SSH keys found for GitHub user '${gh_user}' at ${keys_url}" >&2
  echo "Remove ${cache_file} to re-prompt for a different username." >&2
  exit 1
fi
keys_block="$(printf '%s\n' "${keys}" | sed 's/^/      - /')"

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
