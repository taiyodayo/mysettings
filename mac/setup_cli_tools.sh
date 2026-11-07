#!/usr/bin/env bash
set -euo pipefail

# homebrew はこのスクリプトより前にインストールされている
# Initialize brew in current session (handles architecture automatically)
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"

# Canonical package lists live in packages/*.yml (shared format with the
# Ansible variant). awk extracts package names — no yq dep since yq is
# one of the things we're installing.
PACKAGES_DIR="$SCRIPT_DIR/packages"
# Shared common/ scripts (mise, dart, bun, node, fvm, git_defaults).
MYSETTINGS_DIR="$SCRIPT_DIR"

# ---- Early MAS downloads (Xcode + WireGuard) -----------------------------
# Xcode (497799835) is multi-GB and historically the longest single download
# in this kit. Kick it off NOW, before the bulk brew install, so it streams
# in parallel with the ~50 brew formulae + casks + fonts + rust/uv/Flutter
# downstream. Parent script (setup_mailab_mac.sh) waits on $install_pid at
# the end, so the kit doesn't actually finish before Xcode is on disk.
#
# WireGuard (1451685025, Mac App Store, by Jason A. Donenfeld) is also
# kicked off here — small, but App Store is the preferred install channel
# for VPN clients (sandboxed + entitlement-managed by Apple).
#
# Prereq: user must be signed into the Mac App Store. If not (common in
# Apple Silicon VMs, which disable MAS by design), we warn and skip cleanly
# so the rest of the kit completes; the user can `mas install 497799835
# 1451685025` later once they sign in (or never, if it's a throwaway VM).
#
# The `if ! brew install mas` form is set -e safe — a failure in the if
# condition doesn't trip pipefail. Same for `mas account` below. So even
# a brew flake on the mas formula itself can't sink the rest of the kit.
if ! brew install mas; then
    echo "WARNING: brew install mas failed — skipping App Store installs."
    echo "  → After fixing brew, manually: mas install 497799835 1451685025"
    export install_pid=""
elif ! mas account >/dev/null 2>&1; then
    echo "WARNING: not signed into the Mac App Store (or unavailable — common in Apple Silicon VMs)."
    echo "  → Open the App Store app and sign in, then re-run setup_mailab_mac.sh,"
    echo "    or install Xcode + WireGuard manually after this script completes:"
    echo "      mas install 497799835 1451685025"
    echo "  Continuing without background MAS downloads."
    export install_pid=""
else
    echo "App Store: $(mas account) — starting background downloads (Xcode + WireGuard)"
    nohup mas install 497799835  > /tmp/xcode-install.log     2>&1 &
    export install_pid=$!
    # WireGuard is small + not waited on (orphan completion is fine).
    nohup mas install 1451685025 > /tmp/wireguard-install.log 2>&1 &
fi

# ---- Bulk brew install ---------------------------------------------------
# mas is already on PATH from the early-MAS block; the awk-xargs route
# re-asserts it (no-op) along with the other ~50 formulae + casks + fonts.
awk '/^- / { print $2 }' "$PACKAGES_DIR/darwin_brew_system.yml" \
  | xargs brew install
awk '/^- / { print $2 }' \
    "$PACKAGES_DIR/darwin_brew_casks.yml" \
    "$PACKAGES_DIR/darwin_brew_fonts.yml" \
  | xargs brew install --cask --force

# Add GNU utils to .zshrc (macOS only, idempotent)
if [[ "$OSTYPE" == "darwin"* ]] && ! grep -Fq 'USE_GNU_UTILS' ~/.zshrc 2>/dev/null; then
	if [[ $(uname -m) == "arm64" ]]; then
		# Apple Silicon
		cat >> ~/.zshrc <<- 'EOF'
			# Use GNU coreutils without g prefix
			PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
			PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"
			PATH="/opt/homebrew/opt/grep/libexec/gnubin:$PATH"
			PATH="/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
			PATH="/opt/homebrew/opt/gnu-tar/libexec/gnubin:$PATH"
			PATH="/opt/homebrew/opt/gnu-getopt/bin:$PATH"
			export USE_GNU_UTILS="true"
		EOF
	else
		# Intel
		cat >> ~/.zshrc <<- 'EOF'
			# Use GNU coreutils without g prefix
			PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
			PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
			PATH="/usr/local/opt/grep/libexec/gnubin:$PATH"
			PATH="/usr/local/opt/gnu-sed/libexec/gnubin:$PATH"
			PATH="/usr/local/opt/gnu-tar/libexec/gnubin:$PATH"
			PATH="/usr/local/opt/gnu-getopt/bin:$PATH"
			export USE_GNU_UTILS="true"
		EOF
	fi
	echo "Added GNU utils PATH to .zshrc"
fi

# Xcode + WireGuard MAS downloads were kicked off at the top of this
# script (early-MAS block) so they stream in parallel with brew + the
# downstream tooling installs below. $install_pid is exported from there.

# One declared runtime/tool installation; no shell writes or global gems.
bash "$MYSETTINGS_DIR/common/install_mise.sh"
"$MYSETTINGS_DIR/cli_tools/machine" setup macos-workstation

# git global defaults — shared with the Ubuntu kit. This is a behaviour
# change on Mac (previous Mac kit didn't set git defaults explicitly);
# values match the lab convention used on Ubuntu.
bash "$MYSETTINGS_DIR/common/git_defaults.sh"

# Add custom CLI tools directory to PATH
if [ ! -f ~/.zshrc ] || ! grep -Fq 'mysettings/cli_tools' ~/.zshrc; then
  # shellcheck disable=SC2016
  echo 'export PATH="$HOME/mysettings/cli_tools:$PATH"' >> ~/.zshrc
fi
export PATH="$HOME/mysettings/cli_tools:$PATH"

# Consolidated login check (gh, claude, codex) — reports auth status.
if [ -x "$SCRIPT_DIR/cli_tools/login_check.sh" ]; then
    "$SCRIPT_DIR/cli_tools/login_check.sh"
fi

# Consolidated tool consistency audit. Reports non-canonical installs +
# duplicates of managed CLI tools. Re-run with --fix to auto-purge user-owned
# duplicates. See cli_tools/check_tools.sh --help.
if [ -x "$SCRIPT_DIR/cli_tools/check_tools.sh" ]; then
    "$SCRIPT_DIR/cli_tools/check_tools.sh"
fi

# Display messages
echo "=========================================="
echo "✓ Setup complete!"
echo "=========================================="
