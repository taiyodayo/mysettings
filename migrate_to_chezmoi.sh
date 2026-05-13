#!/usr/bin/env bash
# Opt-in migration to chezmoi-managed dotfiles. Run this on an existing
# kitted machine to switch its ~/.zshrc, ~/.p10k.zsh, ~/.gitconfig,
# ~/.zprofile over to chezmoi-managed copies sourced from
# ~/mysettings/dotfiles/.
#
# Safe to re-run: backups are dated, chezmoi apply is idempotent.
#
# What this does, in order:
#   1. Snapshot existing dotfiles to ~/.dotfiles_backup.<timestamp>/
#   2. Install chezmoi if not already present (brew on Mac, apt on Ubuntu)
#   3. Write ~/.config/chezmoi/chezmoi.toml so chezmoi reads from this repo
#   4. chezmoi apply  — deploy templates to ~/
#   5. Diff backed-up ~/.zshrc vs the new one; surface any orphaned lines
#      so you can decide whether to drop them in ~/.zlocal or ~/.zshrc.local

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_SOURCE="$SCRIPT_DIR/dotfiles"

if [ ! -d "$DOTFILES_SOURCE" ]; then
    echo "ERROR: chezmoi source dir not found at $DOTFILES_SOURCE" >&2
    echo "Pull the latest from the mysettings repo and try again." >&2
    exit 1
fi

# ---- 1. Snapshot existing dotfiles -----------------------------------------
backup_dir="$HOME/.dotfiles_backup.$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"
backed_up=()
for f in .zshrc .p10k.zsh .gitconfig .zprofile .zshenv .zlocal .zshrc.local; do
    if [ -e "$HOME/$f" ]; then
        cp -a "$HOME/$f" "$backup_dir/"
        backed_up+=("$f")
    fi
done
if [ ${#backed_up[@]} -eq 0 ]; then
    echo "No existing dotfiles to back up. Proceeding with fresh install."
    rmdir "$backup_dir"
    backup_dir=""
else
    echo "Backed up ${#backed_up[@]} file(s) to $backup_dir: ${backed_up[*]}"
fi

# ---- 2. Install chezmoi ----------------------------------------------------
if ! command -v chezmoi >/dev/null 2>&1; then
    echo "Installing chezmoi..."
    case "$(uname -s)" in
        Darwin)
            if ! command -v brew >/dev/null 2>&1; then
                echo "ERROR: brew not found. Install Homebrew first." >&2
                exit 1
            fi
            brew install chezmoi
            ;;
        Linux)
            # Prefer apt if it has chezmoi (Ubuntu 24.04+ jammy w/ universe, etc.).
            # Fall back to chezmoi's official one-line installer when apt doesn't
            # have it (Ubuntu 22.04 default repos, non-Debian distros). The
            # installer drops a static binary at ~/.local/bin/chezmoi — no sudo
            # required, and ~/.local/bin is already on PATH via _zshrc.
            if command -v apt-get >/dev/null 2>&1 \
                && sudo apt-get update >/dev/null \
                && apt-cache show chezmoi >/dev/null 2>&1; then
                sudo apt-get install -y chezmoi
            else
                echo "chezmoi not in apt — using official installer to ~/.local/bin/"
                sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
                # Add ~/.local/bin to PATH for the remainder of THIS script run.
                # _zshrc already puts it on PATH for future interactive shells.
                export PATH="$HOME/.local/bin:$PATH"
            fi
            ;;
        *)
            echo "ERROR: unsupported OS: $(uname -s)" >&2
            exit 1
            ;;
    esac
else
    echo "chezmoi already installed: $(chezmoi --version | head -n1)"
fi

# ---- 3. Configure chezmoi to read from this repo's dotfiles/ ---------------
mkdir -p "$HOME/.config/chezmoi"
config_file="$HOME/.config/chezmoi/chezmoi.toml"
cat > "$config_file" <<EOF
# Written by ~/mysettings/migrate_to_chezmoi.sh.
# sourceDir tells chezmoi where to find our templates instead of the default
# ~/.local/share/chezmoi/. Edit if you move the mysettings repo.
sourceDir = "$DOTFILES_SOURCE"
EOF
echo "Wrote $config_file"

# ---- 4. Apply --------------------------------------------------------------
echo "Running chezmoi apply..."
chezmoi apply --force

# ---- 5. Surface orphaned lines from the old ~/.zshrc -----------------------
if [ -n "$backup_dir" ] && [ -f "$backup_dir/.zshrc" ]; then
    orphan_file="$backup_dir/orphaned-from-zshrc.txt"
    # Lines that were in the backup but not in the new file — i.e. content
    # only the user (or a post-kit installer) added.
    diff "$backup_dir/.zshrc" "$HOME/.zshrc" 2>/dev/null \
        | awk '/^< / { sub(/^< /, ""); print }' \
        | grep -v '^[[:space:]]*$' \
        | grep -v '^[[:space:]]*#' \
        > "$orphan_file" || true
    if [ -s "$orphan_file" ]; then
        echo ""
        echo "=========================================="
        echo "Lines from your previous ~/.zshrc that are NOT"
        echo "in the chezmoi-managed one:"
        echo "=========================================="
        cat "$orphan_file"
        echo "=========================================="
        echo "Saved to: $orphan_file"
        echo ""
        echo "To keep any of these, drop them into:"
        echo "  ~/.zlocal           (per-machine config; already sourced by template)"
        echo "  ~/.zshrc.local      (installer additions; sourced last)"
        echo "Both files are untouched by chezmoi apply."
    else
        echo ""
        echo "No orphaned lines — your old ~/.zshrc was fully covered by the template."
        rm -f "$orphan_file"
    fi
fi

cat <<MSG

✓ Migration complete.

Useful commands going forward:
  chezmoi diff               # preview pending changes
  chezmoi edit ~/.zshrc      # edit the template
  chezmoi apply              # re-deploy
  chezmoi add ~/.zshrc       # capture current ~/.zshrc back into the template

Log out and back in (or run \`exec zsh\`) to pick up the new shell config.
MSG
