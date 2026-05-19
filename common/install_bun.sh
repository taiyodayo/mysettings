#!/usr/bin/env bash
# Install bun (JavaScript runtime + package manager).
#
# Per ATTACKPLAN feedback:
#   Mac    → brew install bun                  (brew upgrade keeps it current)
#   Ubuntu → curl https://bun.sh/install | bash → ~/.bun/bin/bun
#            (bun upgrade — its self-update — keeps it current; no apt
#             repo upstream, so this is the closest autoupdating path.)
#
# Both paths run as the target user.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: install_bun.sh must run as the target user, not root." >&2
    exit 1
fi

case "$(uname -s)" in
    Darwin)
        brew install bun
        ;;
    Linux)
        # Bun's installer is idempotent — detects existing install and
        # upgrades in place. Gate on missing binary so re-runs of the
        # whole kit are fast; explicit `bun upgrade` lives elsewhere.
        if ! command -v bun >/dev/null 2>&1 && [ ! -x "$HOME/.bun/bin/bun" ]; then
            curl -fsSL https://bun.sh/install | bash
        fi
        ;;
    *)
        echo "ERROR: install_bun.sh: unsupported OS $(uname -s)" >&2
        exit 1
        ;;
esac
