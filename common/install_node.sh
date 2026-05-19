#!/usr/bin/env bash
# Set node@lts as the global default via mise.
#
# Identical recipe on Mac and Linux. mise must already be installed and
# on PATH (install_mise.sh runs first). `mise use --global` writes
# ~/.config/mise/config.toml directly — no shell-activation needed.
#
# Runs as the target user.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: install_node.sh must run as the target user, not root." >&2
    exit 1
fi

if ! command -v mise >/dev/null 2>&1; then
    echo "ERROR: install_node.sh: mise not found on PATH — run install_mise.sh first." >&2
    exit 1
fi

mise use --global node@lts
