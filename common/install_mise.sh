#!/usr/bin/env bash
# Install mise (the runtime version manager).
#
# Per ATTACKPLAN feedback: prefer autoupdating install paths over pure
# single-command consolidation.
#   Mac    → brew install mise                (brew upgrade keeps it current)
#   Ubuntu → mise.jdx.dev apt repo + apt install mise
#            (apt-get upgrade keeps it current)
#
# Privilege expectations:
#   Mac    — run as the target user (brew runs as user).
#   Ubuntu — run as root (apt-repo + apt install need root). Caller is
#            ubuntu/my_ubuntu_setup.sh's root block.

set -euo pipefail

case "$(uname -s)" in
    Darwin)
        if [[ $EUID -eq 0 ]]; then
            echo "ERROR: install_mise.sh on macOS must run as the target user, not root." >&2
            exit 1
        fi
        # brew is idempotent: no-op if already at latest.
        brew install mise
        ;;
    Linux)
        if [[ $EUID -ne 0 ]]; then
            echo "ERROR: install_mise.sh on Linux must run as root (apt-repo setup)." >&2
            exit 1
        fi
        # gpg + curl come from packages/linux_base.yml (already installed
        # by the time this runs). apt-keyring dir creation is idempotent.
        mkdir -p /etc/apt/keyrings
        # --batch --yes so re-runs overwrite the keyring without prompting.
        curl -fsSL https://mise.jdx.dev/gpg-key.pub \
            | gpg --batch --yes --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
        arch=$(dpkg --print-architecture)
        echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=${arch}] https://mise.jdx.dev/deb stable main" \
            > /etc/apt/sources.list.d/mise.list
        apt-get update
        apt-get install -y mise
        ;;
    *)
        echo "ERROR: install_mise.sh: unsupported OS $(uname -s)" >&2
        exit 1
        ;;
esac
