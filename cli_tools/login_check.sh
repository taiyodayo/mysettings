#!/usr/bin/env bash
# Consolidated login check for LLM and dev CLIs. For each tool that's
# installed on this machine, report whether you're logged in. For tools
# with a clean non-interactive login flow (gh, codex), offer to launch
# the login command. For tools with a TUI-style login (claude, gemini),
# just print the command to run yourself.
#
# Re-runnable anytime. Logged-in tools no-op.
#
# In non-interactive shells (kitting here-docs, cron, CI) prompts are
# skipped automatically — the script reports status and prints the
# command you'd run interactively. This is why calling it at the end
# of the kitting script gives you a checklist, not a blocked install.

set -uo pipefail

# Colors only when stdout is a TTY ------------------------------------------
if [ -t 1 ]; then
    G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[1m'; D=$'\e[2m'; X=$'\e[0m'
else
    G= Y= R= B= D= X=
fi

# Interactive if BOTH stdin and stdout are TTYs (kitting's here-doc gives us
# a non-TTY stdin even when stdout is a terminal).
if [ -t 0 ] && [ -t 1 ]; then
    interactive=true
else
    interactive=false
fi

ok()   { printf "  %s✓%s  %s\n"   "$G" "$X" "$1"; }
nope() { printf "  %s✗%s  %s\n"   "$R" "$X" "$1"; }
skip() { printf "  %s−%s  %s\n"   "$D" "$X" "$1"; }
tell() { printf "       %s%s%s\n" "$D" "$1" "$X"; }

# prompt_run <prompt> <command>
# In interactive mode: asks user [Y/n]. If yes (or empty), eval's the command.
# In non-interactive mode: just prints the command for the user to run later.
prompt_run() {
    local prompt=$1 cmd=$2
    if ! $interactive; then
        tell "To run later: $cmd"
        return
    fi
    local yn
    read -r -p "       → $prompt [Y/n] " yn || true
    case "${yn:-Y}" in
        [Nn]*) tell "To run later: $cmd" ;;
        *)     eval "$cmd" || nope "$cmd: failed (continuing)" ;;
    esac
}

echo
echo "${B}=== Login check ===${X}"

# --- gh -------------------------------------------------------------------
# `gh auth status` exits 0 if logged in for any host. `gh auth login` is
# a bounded interactive flow that exits when done.
if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
        ok "gh: logged in"
    else
        nope "gh: not logged in"
        prompt_run "Log in to gh now?" "gh auth login"
    fi
else
    skip "gh: not installed"
fi

# --- claude (Claude Code native) ------------------------------------------
# No public `claude auth status` CLI yet. The native installer stores
# credentials at ~/.claude/.credentials.json after first /login. We check
# file presence as a heuristic — a stale/expired token would still pass.
if command -v claude >/dev/null 2>&1; then
    if [ -s "$HOME/.claude/.credentials.json" ]; then
        ok "claude: credentials present (~/.claude/.credentials.json)"
    else
        nope "claude: no credentials at ~/.claude/.credentials.json"
        tell "To log in: run \`claude\`, then use the \`/login\` slash command."
    fi
else
    skip "claude: not installed"
fi

# --- codex (OpenAI Codex CLI) ---------------------------------------------
# Heuristic: ~/.codex/auth.json present after login. `codex login` is a
# bounded interactive flow.
if command -v codex >/dev/null 2>&1; then
    if [ -s "$HOME/.codex/auth.json" ]; then
        ok "codex: credentials present (~/.codex/auth.json)"
    else
        nope "codex: no credentials at ~/.codex/auth.json"
        prompt_run "Log in to codex now?" "codex login"
    fi
else
    skip "codex: not installed"
fi

# --- gemini (Google Gemini CLI) -------------------------------------------
# Heuristic: ~/.gemini/oauth_creds.json present after Google OAuth login.
# First-run prompts are TUI-style — print the command rather than auto-launch.
if command -v gemini >/dev/null 2>&1; then
    if [ -s "$HOME/.gemini/oauth_creds.json" ]; then
        ok "gemini: credentials present (~/.gemini/oauth_creds.json)"
    else
        nope "gemini: no credentials at ~/.gemini/oauth_creds.json"
        tell "To log in: run \`gemini\` and follow the interactive prompts."
    fi
else
    skip "gemini: not installed"
fi

echo "${B}=== Done. ===${X}"
echo
