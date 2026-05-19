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
awk '/^- / { print $2 }' "$PACKAGES_DIR/darwin_brew_system.yml" \
  | xargs brew install
awk '/^- / { print $2 }' \
    "$PACKAGES_DIR/darwin_brew_casks.yml" \
    "$PACKAGES_DIR/darwin_brew_fonts.yml" \
  | xargs brew install --cask --force

# bun — shared with the Ubuntu kit (brew on Mac, curl|bash on Ubuntu).
# cli_tools/llms_update.sh uses `bun add -g` for codex/gemini, so bun
# must land before that runs.
bash "$MYSETTINGS_DIR/common/install_bun.sh"

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

# mac App Store CLI (mas) requires user to be signed in
echo "Installing Xcode from Appstore via mas. please login when prompted."
# バックグラウンドで xcode インストールを開始。親側のスクリプトで、 wait $install_pid することでインストール完了を待てる
nohup mas install 497799835 > /tmp/xcode-install.log 2>&1 &
# この値で、親側スクリプトの最後に wait します
export install_pid=$!

# 2025 ruby/cocoapods はもう homebrew で入れるのが主流になった！
brew install ruby cocoapods
BREW_PREFIX="$(brew --prefix)"
export PATH="$BREW_PREFIX/opt/ruby/bin:$PATH"

# dart SDK — shared with the Ubuntu kit. Mac uses brew, Ubuntu uses
# Google's apt repo. fvm 経由でインストールされる Flutter にバンドルされている
# dart sdk が古くなる事があるので、host の dart は最新を維持する。
bash "$MYSETTINGS_DIR/common/install_dart.sh"

# fvm + Flutter — shared with the Ubuntu kit.
export PATH="$HOME/.pub-cache/bin:$PATH"
bash "$MYSETTINGS_DIR/common/install_fvm_flutter.sh"
export PATH="$PATH:$HOME/fvm/default/bin"

# Quick sanity (Mac-specific: flutter doctor is more useful here than on
# headless Linux because Xcode / Android Studio integration is interactive).
fvm --version
flutter --version
flutter doctor
alias ff='fvm flutter'

gem install xcodeproj

# Append FVM/Ruby PATH block to ~/.zshrc once (idempotent)
if ! grep -q '^## BEGIN FVM/Ruby PATH$' ~/.zshrc 2>/dev/null; then
	cat >> ~/.zshrc <<-'EOM'
		## BEGIN FVM/Ruby PATH
		export PATH="$HOME/.pub-cache/bin:$PATH"
		# Homebrew Ruby
		export PATH="$(/opt/homebrew/bin/brew --prefix)/opt/ruby/bin:$PATH"
		# FVM のグローバル Flutter（存在すれば）
		if [ -d "$HOME/fvm/default/bin" ]; then export PATH="$PATH:$HOME/fvm/default/bin"; fi
		alias ff='fvm flutter'
		## END FVM/Ruby PATH
	EOM
fi

# Add Android SDK platform-tools to PATH if not already there
export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
if [ ! -f ~/.zshrc ] || ! grep -Fq 'Android/sdk/platform-tools' ~/.zshrc; then
	cat >> ~/.zshrc <<-'EOM'
		# Android SDK - install from Android Studio SDK Manager separately - cmdline-tools / platform-tools
		export ANDROID_SDK_ROOT="$HOME/Library/Android/sdk"
		export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"
	EOM
fi

# mise — shared with the Ubuntu kit. Mac uses brew; Ubuntu uses the
# mise.jdx.dev apt repo. Both autoupdate via the host's normal upgrade flow.
bash "$MYSETTINGS_DIR/common/install_mise.sh"
# Initialize mise for this current session so the next commands work immediately.
eval "$(mise activate zsh)"
# Add mise to ~/.zshrc if not already there (chezmoi's dot_zshrc.tmpl handles
# this long-term; the inline append keeps pre-chezmoi machines working).
if [ ! -f ~/.zshrc ] || ! grep -Fq 'mise activate zsh' ~/.zshrc; then
  cat >> ~/.zshrc <<-'EOM'
# mise
eval "$(mise activate zsh)"
EOM
fi

# node@lts via mise — shared with the Ubuntu kit.
bash "$MYSETTINGS_DIR/common/install_node.sh"

# rustup + cargo-binstall + 10 cargo CLIs (bat eza rg fd delta dust git-trim
# jless zellij qsv) — shared with the Ubuntu kit. New on Mac in Phase 4:
# these were previously brew formulae; now they live in ~/.cargo/bin with
# upstream-current versions. brew copies (if any) get flagged by
# check_tools.sh and can be uninstalled per its fix_print hints.
bash "$MYSETTINGS_DIR/dotfiles/run_onchange_install-rustup-and-cargo-tools.sh"
# rustup's installer appends `source ~/.cargo/env` to ~/.zshrc; activate
# for THIS shell too so check_tools.sh below sees ~/.cargo/bin on PATH.
# shellcheck source=/dev/null
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# uv + ~/p313 venv + lab DS preload — shared with the Ubuntu kit.
# Mac path: brew already installed uv via darwin_brew_system.yml; the
# common script's `uv self update` is a no-op. ~/p313 holds polars,
# pandas, numpy, etc. (see packages/lab_python.yml). dot_zshrc.tmpl
# sources the venv's activate on every shell; the imperative ~/.zshrc
# append below keeps pre-chezmoi machines working.
bash "$MYSETTINGS_DIR/common/install_uv_and_p313.sh"
if [ ! -f ~/.zshrc ] || ! grep -Fq 'p313/bin/activate' ~/.zshrc; then
    echo 'source ~/p313/bin/activate' >> ~/.zshrc
fi
# shellcheck source=/dev/null
source "$HOME/p313/bin/activate"

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

# Consolidated login check (gh, claude, codex, gemini) — reports auth status.
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
