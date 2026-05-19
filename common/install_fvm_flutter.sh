#!/usr/bin/env bash
# Install Flutter Version Manager (fvm) via `dart pub global activate`,
# then install + pin Flutter stable. Identical recipe on Mac and Linux.
#
# Requires dart on PATH (install_dart.sh runs first).
#
# Runs as the target user. ~/.pub-cache/bin and ~/fvm get populated.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: install_fvm_flutter.sh must run as the target user, not root." >&2
    exit 1
fi

if ! command -v dart >/dev/null 2>&1; then
    echo "ERROR: install_fvm_flutter.sh: dart not found on PATH — run install_dart.sh first." >&2
    exit 1
fi

# Make pub-cache/bin and fvm/default/bin discoverable during the rest of
# this script — the user's interactive zshrc handles PATH long-term via
# dotfiles, but this script needs them right now.
export PATH="$HOME/.pub-cache/bin:$HOME/fvm/default/bin:$PATH"

dart pub global activate fvm

# `fvm install stable` downloads ~500MB — skip if we already have it.
if [ ! -d "$HOME/fvm/versions/stable" ]; then
    fvm install stable
fi
fvm global stable
