#!/usr/bin/env bash
# Install or update rustup + cargo-installed CLIs.
# Re-runs whenever this file's content hash changes (chezmoi run_onchange_).
# Also invoked directly by the kit scripts (ubuntu/my_ubuntu_setup.sh,
# automated/ubuntu_kitting.yml, mac/setup_cli_tools.sh) — chezmoi-driven
# kits are Phase 6+, so today the kit drives this.
#
# Cross-platform: works identically on Mac and Linux. ~/.cargo lives in
# $HOME on both. Runs as the target user.
#
# Tool inventory (canonical home: ~/.cargo/bin):
#   bat eza ripgrep fd-find git-delta du-dust git-trim jless zellij qsv
# Phase 4 moved bat/eza/ripgrep/fd-find/git-delta off apt+brew so the host
# keeps up with upstream feature releases. cargo-binstall pulls prebuilt
# GitHub-release binaries (~1 min total) instead of source-compiling
# (~35 min total — qsv alone ~10 min).
#
# Ubuntu assumption: my_ubuntu_setup.sh purges apt's rustc/cargo in the
# root block. chezmoi runs as the user — we can't apt purge from here.

set -euo pipefail

# --- rustup ---------------------------------------------------------------
if command -v rustup >/dev/null 2>&1; then
    rustup self update
    rustup update stable
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain stable
fi

# Source cargo env so the rest of this script can resolve `cargo`.
# (Won't affect the calling shell — this script runs in a subshell.)
# shellcheck source=/dev/null
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# --- cargo-binstall -------------------------------------------------------
# Pulls upstream prebuilt binaries from GitHub releases instead of
# source-compiling. Falls back to `cargo install` automatically when no
# binstall release exists for a given crate.
if ! command -v cargo-binstall >/dev/null 2>&1; then
    curl -L --proto '=https' --tlsv1.2 -sSf \
        https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh \
      | bash
fi

# --- cargo tools ----------------------------------------------------------
# Per-tool tolerant: a single failure prints a warning and continues so
# one flaky download / missing system lib doesn't sink the rest of the
# install. cargo binstall is itself idempotent — re-running is fast (one
# version-check HTTP round-trip per crate).
#
# install_one <crate> [features]
#   crate:    cargo crate name (e.g. "ripgrep", "git-delta")
#   features: optional cargo features, comma-separated (e.g. "apply")
install_one() {
    local crate=$1
    local features=${2:-}
    local args=(--locked --no-confirm "$crate")
    if [ -n "$features" ]; then
        args+=(--features "$features")
    fi
    if ! cargo binstall "${args[@]}"; then
        echo "WARN: cargo binstall $crate failed — continuing." >&2
        return 0
    fi
}

install_one bat
install_one eza
install_one ripgrep
install_one fd-find
install_one git-delta
install_one du-dust
install_one git-trim
install_one jless
install_one zellij
install_one qsv apply
