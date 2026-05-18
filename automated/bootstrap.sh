#!/usr/bin/env bash
# Bootstrap everything required to run `make kit` (the Ansible-based ubuntu
# kitting playbook). The shell version of kitting (ubuntu/my_ubuntu_setup.sh)
# requires no bootstrap; this script is the moral equivalent for the Ansible
# path.
#
# Installs:
#   1. apt prereqs           — python3-venv, pipx, snapd, git, curl,
#                              ca-certificates. apt-installed ansible (if any)
#                              is purged because it ships 2.10.x on Ubuntu
#                              22.04 / 24.04, which is too old for our
#                              community.general 8+ collection requirement.
#   2. ansible via pipx      — current upstream version, per-user under
#                              ~/.local/pipx/venvs/ansible. Does not pollute
#                              system Python. PATH addition handled by
#                              `pipx ensurepath` (writes to shell rc).
#   3. Galaxy collections    — community.general, ansible.posix
#                              (versions pinned in requirements.yml).
#
# Re-entrant — every step is idempotent:
#   - apt-get install is a no-op on already-installed packages
#   - pipx install / upgrade is gated on detection
#   - ansible-galaxy collection install short-circuits when the requested
#     version is already present
#
# Usage:
#   bash automated/bootstrap.sh
#   cd automated && make kit          # once bootstrap completes
#
# DO NOT run as root: pipx installs per-user. The script invokes sudo only
# where it has to (apt).

set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: do NOT run as root." >&2
    echo "  pipx installs ansible per-user (~/.local/pipx). Run as your" >&2
    echo "  normal user; sudo is used per-step where needed." >&2
    exit 1
fi

# Run from the directory containing this script so requirements.yml is found
# regardless of where the user invoked us from.
script_dir="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$script_dir"

# Color helpers only on TTY.
if [ -t 1 ]; then
    G=$'\e[32m'; B=$'\e[1m'; D=$'\e[2m'; X=$'\e[0m'
else
    G= B= D= X=
fi
step() { printf "%s==> %s%s\n" "$B" "$1" "$X"; }
note() { printf "    %s%s%s\n" "$D" "$1" "$X"; }

# ---------------------------------------------------------------------------
# 1. apt prereqs
# ---------------------------------------------------------------------------
step "[1/3] apt prereqs (python3-venv, pipx, snapd, git, curl, ca-certificates)"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    python3 python3-venv pipx snapd git curl ca-certificates

# Drop apt's ansible if present — too old. apt-get purge returns 0 when the
# package isn't installed, so this stays idempotent.
if dpkg-query -W -f='${Status}' ansible 2>/dev/null | grep -q "install ok installed"; then
    note "removing apt ansible 2.10 (community.general >=8 needs ansible-core >=2.13)"
    sudo apt-get purge -y ansible
fi

# pipx ensurepath: idempotent; adds ~/.local/bin to PATH via shell rc and is
# a no-op when already present. We also export it inline so the rest of THIS
# script can find pipx-installed binaries without the user re-sourcing.
pipx ensurepath >/dev/null
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# 2. ansible via pipx
# ---------------------------------------------------------------------------
step "[2/3] ansible via pipx"
# --include-deps so ansible-playbook / ansible-galaxy / etc. (entry points
# defined by ansible-core, a dependency of the `ansible` distro package) are
# also linked into ~/.local/bin.
if pipx list --short 2>/dev/null | grep -qE "^ansible "; then
    note "ansible already pipx-installed; upgrading to latest"
    pipx upgrade ansible >/dev/null
else
    pipx install --include-deps ansible
fi

# Sanity: make sure `ansible` now resolves to the pipx one, not some leftover.
ansible_path=$(command -v ansible 2>/dev/null || true)
if [ -z "$ansible_path" ]; then
    echo "ERROR: ansible not on PATH after pipx install." >&2
    echo "  Expected ~/.local/bin/ansible. Check that pipx ensurepath worked," >&2
    echo "  then re-run." >&2
    exit 1
fi
note "ansible: $ansible_path"

# ---------------------------------------------------------------------------
# 3. Galaxy collections
# ---------------------------------------------------------------------------
step "[3/3] Galaxy collections (per requirements.yml)"
# ansible-galaxy collection install is idempotent — it's a no-op when the
# requested version is already present.
ansible-galaxy collection install -r requirements.yml

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
echo
echo "${G}${B}✓ Bootstrap complete.${X}"
echo
ansible --version | head -2
echo
ansible-galaxy collection list 2>/dev/null \
    | grep -E "^(community\.general|ansible\.posix)\s" || true
echo
echo "Next:"
echo "    cd $script_dir && make kit"
echo
echo "If \`ansible\` isn't found in a new shell, run \`pipx ensurepath\` once"
echo "and start a fresh login shell — pipx writes the PATH update to ~/.bashrc"
echo "or ~/.zshrc but it doesn't take effect in the current shell."
