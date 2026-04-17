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
# Migrates any existing bun/npm global install to native, then self-updates.
update_claude_native() {
    local CMD_NAME="claude"
    local NATIVE_PATH="$HOME/.local/bin/claude"
    local PKG="@anthropic-ai/claude-code"
    echo -n "Processing $CMD_NAME (native installer)... "

    local OLD_VER
    OLD_VER=$(get_version "$CMD_NAME")

    # Detect whether the current install is the native one at ~/.local/bin/claude.
    local IS_NATIVE=false
    if [ "$OLD_VER" != "Not Installed" ]; then
        local CUR_PATH
        CUR_PATH=$(command -v "$CMD_NAME")
        if [ "$CUR_PATH" = "$NATIVE_PATH" ]; then
            IS_NATIVE=true
        fi
    fi

    # If a non-native (bun/npm) install is present, remove it before installing native.
    if [ "$OLD_VER" != "Not Installed" ] && [ "$IS_NATIVE" = false ]; then
        echo ""
        echo "  Detected non-native $CMD_NAME at $(command -v $CMD_NAME) — migrating to native."
        if command -v bun &>/dev/null; then
            bun remove -g "$PKG" >/dev/null 2>&1 || true
        fi
        if command -v npm &>/dev/null; then
            npm uninstall -g "$PKG" >/dev/null 2>&1 || true
        fi
        hash -r
        echo -n "  Installing $CMD_NAME via native installer... "
    fi

    local UPDATE_LOG
    if [ "$IS_NATIVE" = true ]; then
        # Native install already present — let claude update itself.
        if ! UPDATE_LOG=$("$CMD_NAME" update 2>&1); then
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