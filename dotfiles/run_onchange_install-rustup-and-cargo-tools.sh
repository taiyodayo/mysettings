#!/usr/bin/env bash
# Install or update rustup + cargo-installed CLIs.
# Re-runs whenever this file's content hash changes (chezmoi run_onchange_).
# Adding a `cargo install` line below = next chezmoi apply installs it.
#
# Cross-platform: rustup's curl-pipe-sh installer works identically on
# Mac and Linux. ~/.cargo lives in $HOME on both.
#
# Assumption on Ubuntu: my_ubuntu_setup.sh has already purged apt's
# rustc/cargo (it does this in the base apt section). chezmoi runs as
# the user — we can't apt purge from here.

set -euo pipefail

if command -v rustup >/dev/null 2>&1; then
    rustup self update
    rustup update stable
else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
      | sh -s -- -y --default-toolchain stable
fi

# Source cargo env so `cargo install` below resolves in THIS subprocess.
# (Won't affect the calling shell — chezmoi runs scripts in a subshell.)
# shellcheck source=/dev/null
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Cargo-installed CLIs. `cargo install` is idempotent: it skips when the
# requested version is already installed and rebuilds only on upgrade.
# --locked uses the crate's pinned Cargo.lock for deterministic builds.
cargo install --locked git-trim
