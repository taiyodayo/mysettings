#!/usr/bin/env bash
# Bootstrap everything required to run `make kitting` (the Ansible-based
# cross-platform kitting playbook). The shell variants
# (ubuntu/my_ubuntu_setup.sh + mac/setup_cli_tools.sh) require no
# bootstrap; this script is the moral equivalent for the Ansible path.
#
# Cross-platform:
#   Linux  → apt prereqs + pipx + ansible per-user. apt-installed ansible
#            (if any) is purged because Ubuntu ships 2.10.x, too old for
#            community.general >=8.
#   Darwin → brew install ansible. Modern-tooling preference: brew on
#            Mac autoupdates via `brew upgrade`; pipx is overkill when
#            brew already has a current ansible formula.
#
# Common (both OSes):
#   - Galaxy collections (community.general, ansible.posix) per
#     requirements.yml. Idempotent — `ansible-galaxy collection install`
#     is a no-op when the requested version is already present.
#
# Re-entrant — every step is idempotent.
#
# Usage:
#   bash automated/bootstrap.sh
#   cd automated && make kitting     # once bootstrap completes
#
# DO NOT run as root: pipx and brew both install per-user. The script
# invokes sudo only where it has to (apt on Linux).

set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: do NOT run as root." >&2
    echo "  pipx (Linux) / brew (Mac) install per-user. Run as your normal" >&2
    echo "  user; sudo is used per-step where needed (Linux only)." >&2
    exit 1
fi

# Run from the directory containing this script so requirements.yml is found
# regardless of where the user invoked us from. readlink -f on macOS
# requires coreutils (BSD readlink doesn't grok -f) — fall back via cd-pwd.
if command -v greadlink >/dev/null 2>&1; then
    script_dir="$(cd "$(dirname "$(greadlink -f "$0")")" && pwd)"
elif readlink -f / >/dev/null 2>&1; then
    script_dir="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
else
    # BSD readlink (default Mac, pre-coreutils): use the cd-pwd dance.
    script_dir="$(cd "$(dirname "$0")" && pwd)"
fi
cd "$script_dir"

# Color helpers only on TTY.
if [ -t 1 ]; then
    G=$'\e[32m'; B=$'\e[1m'; D=$'\e[2m'; X=$'\e[0m'
else
    G= B= D= X=
fi
step() { printf "%s==> %s%s\n" "$B" "$1" "$X"; }
note() { printf "    %s%s%s\n" "$D" "$1" "$X"; }

case "$(uname -s)" in
    Linux)
        # -------------------------------------------------------------------
        # Linux: apt prereqs + pipx ansible
        # -------------------------------------------------------------------
        step "[1/3] apt prereqs (python3-venv, pipx, snapd, git, curl, ca-certificates)"
        sudo apt-get update
        sudo apt-get install -y --no-install-recommends \
            python3 python3-venv pipx snapd git curl ca-certificates

        # Drop apt's ansible if present — too old. apt-get purge returns 0
        # when the package isn't installed, so this stays idempotent.
        if dpkg-query -W -f='${Status}' ansible 2>/dev/null | grep -q "install ok installed"; then
            note "removing apt ansible 2.10 (community.general >=8 needs ansible-core >=2.13)"
            sudo apt-get purge -y ansible
        fi

        # pipx ensurepath: idempotent; adds ~/.local/bin to PATH via shell rc.
        pipx ensurepath >/dev/null
        export PATH="$HOME/.local/bin:$PATH"

        step "[2/3] ansible via pipx"
        # --include-deps so ansible-playbook / ansible-galaxy entry points
        # (defined by ansible-core, a dep of the `ansible` distro package)
        # are also linked into ~/.local/bin.
        if pipx list --short 2>/dev/null | grep -qE "^ansible "; then
            note "ansible already pipx-installed; upgrading to latest"
            pipx upgrade ansible >/dev/null
        else
            pipx install --include-deps ansible
        fi
        ;;

    Darwin)
        # -------------------------------------------------------------------
        # Mac: brew ansible (autoupdates via brew upgrade)
        # -------------------------------------------------------------------
        step "[1/2] brew install ansible"
        if ! command -v brew >/dev/null 2>&1; then
            echo "ERROR: brew is not installed. Install Homebrew first:" >&2
            # shellcheck disable=SC2016
            echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
            exit 1
        fi
        # brew install is idempotent (no-op when current); brew upgrade
        # happens on the host's regular `brew upgrade` cycle (or via the
        # `mas`-style brew-autoupgrade workflow if the user has one).
        brew install ansible
        # Make /opt/homebrew/bin / /usr/local/bin findable in this shell
        # in case the user hasn't sourced brew shellenv in their rc yet.
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
        step "[2/2] ansible via brew"
        ;;

    *)
        echo "ERROR: unsupported OS $(uname -s)" >&2
        exit 1
        ;;
esac

# Sanity: ansible must be on PATH for the Galaxy step + future `make kitting`.
ansible_path=$(command -v ansible 2>/dev/null || true)
if [ -z "$ansible_path" ]; then
    echo "ERROR: ansible not on PATH after install." >&2
    echo "  On Linux: ensure 'pipx ensurepath' wrote ~/.local/bin to your rc." >&2
    echo "  On Mac:   ensure /opt/homebrew/bin (or /usr/local/bin) is on PATH." >&2
    exit 1
fi
note "ansible: $ansible_path"

# ---------------------------------------------------------------------------
# Common: Galaxy collections
# ---------------------------------------------------------------------------
step "Galaxy collections (per requirements.yml)"
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
echo "    cd $script_dir && make kitting    # cross-platform"
echo
case "$(uname -s)" in
    Linux)
        echo "If \`ansible\` isn't found in a new shell, run \`pipx ensurepath\` once"
        echo "and start a fresh login shell — pipx writes the PATH update to ~/.bashrc"
        echo "or ~/.zshrc but it doesn't take effect in the current shell."
        ;;
    Darwin)
        echo "If \`ansible\` isn't found in a new shell, ensure your ~/.zshrc sources"
        echo "\`brew shellenv\` (the dotfiles/dot_zshrc.tmpl handles this for managed"
        echo "shells; chezmoi apply lays it down)."
        ;;
esac
