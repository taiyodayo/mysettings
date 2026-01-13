#!/usr/bin/env bash
set -euo pipefail

# Function to handle the version check and update logic
update_tool() {
    local CMD_NAME=$1       # The command you type (e.g., gemini)
    local PACKAGE_NAME=$2   # The npm/bun package name (e.g., @google/gemini-cli)

    # Print processing status (will be overwritten later)
    echo -n "Processing $CMD_NAME... "

    # 1. Capture Old Version
    if command -v "$CMD_NAME" &> /dev/null; then
        # '|| echo "Unknown"' prevents script crash if grep finds no version number
        OLD_VER=$($CMD_NAME --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "Unknown")
        [ -z "$OLD_VER" ] && OLD_VER="Unknown"
    else
        OLD_VER="Not Installed"
    fi

    # 2. Run the Update
    if UPDATE_LOG=$(bun add -g "$PACKAGE_NAME" 2>&1); then
        # Success path
        :
    else
        # Failure path
        echo ""
        echo "❌ $CMD_NAME - Critical Error: Update command failed."
        echo "LOG OUTPUT:"
        echo "$UPDATE_LOG"
        return 1
    fi

    # 3. Capture New Version
    if command -v "$CMD_NAME" &> /dev/null; then
        NEW_VER=$($CMD_NAME --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || echo "Unknown")
        [ -z "$NEW_VER" ] && NEW_VER="Unknown"
    else
        echo ""
        echo "❌ $CMD_NAME - Error: Installation appeared successful, but command not found."
        return 1
    fi

    # 4. Compare and Notify
    # \r overwrites the "Processing..." text
    if [ "$OLD_VER" != "$NEW_VER" ]; then
        if [ "$OLD_VER" == "Not Installed" ]; then
            echo -e "\r$CMD_NAME - installed fresh : $NEW_VER          "
        elif [ "$OLD_VER" == "Unknown" ]; then
            # New condition: Old version was broken/unreadable
            echo -e "\r$CMD_NAME - \033[0;33mrepaired\033[0m $OLD_VER -> $NEW_VER          "
        else
            echo -e "\r$CMD_NAME - \033[0;32mupdate installed\033[0m $OLD_VER -> $NEW_VER          "
        fi
    else
        echo -e "\r$CMD_NAME - no updates. current version : $NEW_VER          "
    fi
}

# --- RUN UPDATES ---

# 1. Google Gemini
update_tool "gemini" "@google/gemini-cli"

# 2. Claude Code
update_tool "claude" "@anthropic-ai/claude-code"

# 3. Codex
update_tool "codex" "@openai/codex"