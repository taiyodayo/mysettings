#!/usr/bin/env bash
# Install or update uv (astral.sh) Python toolchain.
# Re-runs whenever this file's content hash changes (chezmoi run_onchange_).
#
# Cross-platform: same curl-pipe-sh recipe on Mac and Linux. If uv was
# already installed by another mechanism (brew, apt), `uv self update`
# is a quiet no-op when the install method doesn't support self-update,
# leaving things alone. Otherwise it pulls the latest astral.sh release.

set -euo pipefail

if command -v uv >/dev/null 2>&1; then
    # No-op if uv was installed via package manager (brew on Mac, apt
    # elsewhere). Errors are tolerated — we don't want to fail apply
    # just because a package-managed uv can't self-update.
    uv self update 2>/dev/null || true
else
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi
