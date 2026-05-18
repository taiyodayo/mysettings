#!/usr/bin/env bash
# Top-level Ubuntu kitting entry point — Ansible variant.
#
# Direct runnable equivalent of ./setup_mailab_ubuntu.sh. Same UX:
#
#   git clone <repo> ~/mysettings
#   cd ~/mysettings
#   ./setup_mailab_ubuntu-ansible.sh
#
# Single sudo prompt at the start; the rest runs unattended (a background
# sudo keep-alive prevents the cache from expiring during long cargo builds).
# Re-entrant — safe to re-run after a partial setup.
#
# Optional flags:
#   --no-github-key   skip the GitHub ed25519 SSH key prompt + import
#   --help, -h        show this help
#
# Orchestrates the three Ansible-variant steps:
#   1. automated/bootstrap.sh        — pipx + ansible + Galaxy collections
#   2. ansible-playbook zsh_and_keys.yml -e github_username=…
#   3. ansible-playbook ubuntu_kitting.yml

set -euo pipefail

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "ERROR: this script is for Ubuntu/Linux. Use ./setup_mailab_mac.sh on Mac." >&2
    exit 1
fi
if [[ "$EUID" -eq 0 ]]; then
    echo "ERROR: run as your normal user, NOT as root." >&2
    echo "  bootstrap installs ansible per-user via pipx; sudo is invoked" >&2
    echo "  per-step where needed." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Repo must live at ~/mysettings — _zshrc, PATH additions, and various
# SCRIPT_DIR defaults hardcode this path. Refuse early so re-cloning is the
# obvious next step instead of a silent broken environment after kitting.
if [[ "$SCRIPT_DIR" != "$HOME/mysettings" ]]; then
    echo "ERROR: this repo must be cloned at ~/mysettings (currently $SCRIPT_DIR)." >&2
    echo "  _zshrc and the kitting playbook hardcode ~/mysettings paths." >&2
    echo "  Move or re-clone to ~/mysettings and re-run." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
skip_key=false
for arg in "$@"; do
    case "$arg" in
        --no-github-key) skip_key=true ;;
        -h|--help)
            sed -n '2,21p' "$0" | sed 's/^# \?//'
            exit 0 ;;
        *)
            echo "Unknown flag: $arg" >&2
            echo "Try --help" >&2
            exit 2 ;;
    esac
done

# ---------------------------------------------------------------------------
# GitHub username prompt (matches common/setup_zsh_and_keys.sh semantics)
# ---------------------------------------------------------------------------
github_user=""
if ! $skip_key; then
    if [ -f ~/.ssh/authorized_keys ] && grep -q '^ssh-ed25519 ' ~/.ssh/authorized_keys; then
        echo "ed25519 key already in ~/.ssh/authorized_keys — skipping GitHub key import."
        skip_key=true
    else
        while true; do
            read -r -p "GitHub username for ed25519 SSH key fetch (ENTER to skip): " github_user
            if [ -z "$github_user" ]; then
                echo "  Skipping GitHub key import."
                skip_key=true
                break
            fi
            # Sanitize: alphanumeric + hyphen, max 39 chars (GitHub limit).
            sanitized=${github_user//[^a-zA-Z0-9-]/}
            sanitized=${sanitized:0:39}
            if [ -z "$sanitized" ]; then
                echo "  Empty/invalid after sanitization, try again."
                continue
            fi
            github_user=$sanitized
            break
        done
    fi
fi

# ---------------------------------------------------------------------------
# Single sudo prompt + background keep-alive
# ---------------------------------------------------------------------------
# Validates and caches the sudo password once. Background loop refreshes
# the cache every 60s so kit (which can take 20–30 minutes during cargo
# builds) doesn't hit a re-prompt mid-run. Trap kills the loop on exit.
echo
echo "sudo authentication (one prompt; cached for the rest of the run):"
sudo -v
( while true; do sudo -n true; sleep 60; kill -0 $$ 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE_PID=$!
# shellcheck disable=SC2064
trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null || true" EXIT

# ---------------------------------------------------------------------------
# Step 1: bootstrap ansible (pipx + Galaxy collections + apt prereqs)
# ---------------------------------------------------------------------------
echo
echo "=== Step 1/3: bootstrap (pipx + ansible + Galaxy collections) ==="
bash automated/bootstrap.sh
# Make pipx-installed ansible findable in this same shell for steps 2/3.
export PATH="$HOME/.local/bin:$PATH"

# Sanity check: bootstrap should have produced a working ansible-playbook.
if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "ERROR: ansible-playbook not on PATH after bootstrap." >&2
    echo "  Expected ~/.local/bin/ansible-playbook. Bootstrap may have failed silently." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 2: zsh + (optional) GitHub SSH key import
# ---------------------------------------------------------------------------
echo
echo "=== Step 2/3: zsh + SSH keys ==="
cd automated
if $skip_key; then
    ansible-playbook zsh_and_keys.yml
else
    ansible-playbook zsh_and_keys.yml -e github_username="$github_user"
fi

# ---------------------------------------------------------------------------
# Step 3: full ubuntu kitting
# ---------------------------------------------------------------------------
echo
echo "=== Step 3/3: ubuntu kitting ==="
ansible-playbook ubuntu_kitting.yml

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo
echo "=========================================="
echo "✓ Ubuntu kitting complete (Ansible variant)."
echo "=========================================="
echo "  Log out and back in to land in zsh + pick up the docker group."
