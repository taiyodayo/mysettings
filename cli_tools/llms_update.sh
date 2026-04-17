#!/usr/bin/env bash
set -euo pipefail

# Ensure the native Claude Code install location is on PATH for this script
export PATH="$HOME/.local/bin:$PATH"

# Report version change (or no-change) using the same format across installers
report_version_change() {
    local CMD_NAME=$1
    local OLD_VER=$2
    local NEW_VER=$3

    if [ "$OLD_VER" != "$NEW_VER" ]; then
        if [ "$OLD_VER" == "Not Installed" ]; then
            echo -e "\r$CMD_NAME - installed fresh : $NEW_VER          "
        elif [ "$OLD_VER" == "Unknown" ]; then
            echo -e "\r$CMD_NAME - \033[0;33mrepaired\033[0m $OLD_VER -> $NEW_VER          "
        else
            echo -e "\r$CMD_NAME - \033[0;32mupdate installed\033[0m $OLD_VER -> $NEW_VER          "
        fi
    else
        echo -e "\r$CMD_NAME - no updates. current version : $NEW_VER          "
    fi
}

# Read installed version, or return "Not Installed" / "Unknown"
get_version() {
    local CMD_NAME=$1
    if command -v "$CMD_NAME" &> /dev/null; then
        local VER
        VER=$("$CMD_NAME" --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "Unknown")
        [ -z "$VER" ] && VER="Unknown"
        echo "$VER"
    else
        echo "Not Installed"
    fi
}

# Update Claude Code via the native installer (https://claude.ai/install.sh).
# Always purges any bun/npm/volta global install of @anthropic-ai/claude-code
# (even if a native install is already first in PATH), then installs/self-updates.
update_claude_native() {
    local CMD_NAME="claude"
    local NATIVE_PATH="$HOME/.local/bin/claude"
    local PKG="@anthropic-ai/claude-code"
    echo -n "Processing $CMD_NAME (native installer)... "

    local OLD_VER
    OLD_VER=$(get_version "$CMD_NAME")

    # Purge residual non-native installs from known locations. Runs unconditionally
    # because a native install may be first in PATH while bun/volta copies linger.
    local CLEANED=""
    # bun (~/.bun/bin/claude)
    if [ -e "$HOME/.bun/bin/claude" ]; then
        if command -v bun &>/dev/null; then
            bun remove -g "$PKG" >/dev/null 2>&1 || true
        fi
        rm -f "$HOME/.bun/bin/claude"
        CLEANED="$CLEANED bun"
    fi
    # volta (~/.volta/bin/claude shim)
    if [ -e "$HOME/.volta/bin/claude" ]; then
        if command -v volta &>/dev/null; then
            volta uninstall "$PKG" >/dev/null 2>&1 \
                || volta uninstall claude >/dev/null 2>&1 \
                || true
        fi
        rm -f "$HOME/.volta/bin/claude"
        CLEANED="$CLEANED volta"
    fi
    # npm global
    if command -v npm &>/dev/null; then
        local NPM_ROOT
        NPM_ROOT=$(npm root -g 2>/dev/null || true)
        if [ -n "$NPM_ROOT" ] && [ -d "$NPM_ROOT/@anthropic-ai/claude-code" ]; then
            npm uninstall -g "$PKG" >/dev/null 2>&1 || true
            CLEANED="$CLEANED npm"
        fi
    fi

    if [ -n "$CLEANED" ]; then
        echo ""
        echo "  Removed non-native $CMD_NAME from:$CLEANED"
        hash -r
        echo -n "  Finishing $CMD_NAME install/update... "
    fi

    # After cleanup, decide install vs update based on the native binary's presence.
    local HAS_NATIVE=false
    [ -x "$NATIVE_PATH" ] && HAS_NATIVE=true

    local UPDATE_LOG
    if [ "$HAS_NATIVE" = true ]; then
        # Native install present — invoke it directly so we don't hit a stale shim.
        if ! UPDATE_LOG=$("$NATIVE_PATH" update 2>&1); then
            echo ""
            echo "❌ $CMD_NAME - Critical Error: 'claude update' failed."
            echo "LOG OUTPUT:"
            echo "$UPDATE_LOG"
            return 1
        fi
    else
        # Fresh install or migration — run the official curl | bash installer.
        if ! UPDATE_LOG=$(curl -fsSL https://claude.ai/install.sh | bash 2>&1); then
            echo ""
            echo "❌ $CMD_NAME - Critical Error: native installer failed."
            echo "LOG OUTPUT:"
            echo "$UPDATE_LOG"
            return 1
        fi
    fi

    # Re-resolve PATH in case the installer just created ~/.local/bin/claude
    hash -r
    local NEW_VER
    NEW_VER=$(get_version "$CMD_NAME")
    if [ "$NEW_VER" == "Not Installed" ]; then
        echo ""
        echo "❌ $CMD_NAME - Error: installation appeared successful, but command not found."
        echo "   The native installer places the binary at ~/.local/bin/claude."
        echo "   Ensure that directory is on your PATH."
        return 1
    fi

    report_version_change "$CMD_NAME" "$OLD_VER" "$NEW_VER"
}

# Function to handle the version check and update logic
update_tool() {
    local CMD_NAME=$1       # The command you type (e.g., gemini)
    local PACKAGE_NAME=$2   # The npm/bun package name (e.g., @google/gemini-cli)

    echo -n "Processing $CMD_NAME... "

    local OLD_VER
    OLD_VER=$(get_version "$CMD_NAME")

    local UPDATE_LOG
    if ! UPDATE_LOG=$(bun add -g "$PACKAGE_NAME" 2>&1); then
        echo ""
        echo "❌ $CMD_NAME - Critical Error: Update command failed."
        echo "LOG OUTPUT:"
        echo "$UPDATE_LOG"
        return 1
    fi

    hash -r
    local NEW_VER
    NEW_VER=$(get_version "$CMD_NAME")
    if [ "$NEW_VER" == "Not Installed" ]; then
        echo ""
        echo "❌ $CMD_NAME - Error: Installation appeared successful, but command not found."
        return 1
    fi

    report_version_change "$CMD_NAME" "$OLD_VER" "$NEW_VER"
}

# --- RUN UPDATES ---

# 1. Google Gemini
update_tool "gemini" "@google/gemini-cli"

# 2. Claude Code (native installer)
update_claude_native

# 3. Codex
update_tool "codex" "@openai/codex"