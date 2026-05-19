#!/usr/bin/env bash
# Tool consistency audit. Compares each managed CLI tool's actual install
# location against the canonical path defined by this repo's kitting scripts.
# Reports duplicates and non-canonical installs.
#
# Usage:
#   check_tools.sh           # report only (default; never modifies)
#   check_tools.sh --fix     # also remove non-canonical copies in user-owned
#                            # locations (bat/eza in ~/.cargo, claude in
#                            # ~/.bun or ~/.volta, etc.). Sudo-required fixes
#                            # are printed, never executed.
#   check_tools.sh --strict  # exit non-zero if any issues found (for CI)
#
# Re-runnable. Default mode is read-only.
#
# Groups:
#   1 — strong consolidation: claude, rustc/cargo, bat, eza, gh, mise, node, uv
#                             (auto-fixable in user-owned dirs)
#   2 — warn-only:            ruby, fvm/flutter mixing
#   3 — no enforcement:       chezmoi (apt or curl both OK), direnv, bun

set -uo pipefail

FIX=false
STRICT=false
for arg in "$@"; do
    case "$arg" in
        --fix)    FIX=true ;;
        --strict) STRICT=true ;;
        -h|--help)
            sed -n '2,21p' "$0" | sed 's/^# \?//'
            exit 0 ;;
        *) echo "Unknown arg: $arg" >&2; exit 2 ;;
    esac
done

# Colors only on TTY
if [ -t 1 ]; then
    G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[1m'; D=$'\e[2m'; X=$'\e[0m'
else
    G= Y= R= B= D= X=
fi

issues=0

ok()       { printf "  %s✓%s  %s\n"       "$G" "$X" "$1"; }
warn()     { printf "  %s⚠%s  %s\n"       "$Y" "$X" "$1"; issues=$((issues + 1)); }
fail()     { printf "  %s✗%s  %s\n"       "$R" "$X" "$1"; issues=$((issues + 1)); }
skip()     { printf "  %s−%s  %s\n"       "$D" "$X" "$1"; }
note()     { printf "       %s%s%s\n"     "$D" "$1" "$X"; }
fixmsg()   { printf "       %s(fix) %s%s\n"   "$D" "$1" "$X"; }
acted()    { printf "       %s(fixed) %s%s\n" "$G" "$1" "$X"; }

OS=$(uname -s)
# brew_prefix: empty if brew not installed.
brew_prefix=""
if command -v brew >/dev/null 2>&1; then
    brew_prefix=$(brew --prefix 2>/dev/null || echo "")
fi

# fix_remove <description> <path> [canonical_path]
# In --fix mode: rm -f the file, but ONLY if canonical_path is present
# (or no canonical specified). This prevents --fix from removing the
# only remaining copy of a tool when the canonical install is broken.
fix_remove() {
    local desc=$1 path=$2 canonical=${3:-}
    if [ ! -e "$path" ]; then
        return
    fi
    # Refuse to remove if canonical is required and missing.
    # (Glob-canonicals like ~/.local/share/mise/installs/node/* are checked
    #  with a shell glob; non-glob canonicals use plain -e.)
    if [ -n "$canonical" ]; then
        local canonical_ok=0
        if [[ "$canonical" == *"*"* ]]; then
            # shellcheck disable=SC2086
            for cand in $canonical; do
                [ -e "$cand" ] && { canonical_ok=1; break; }
            done
        else
            [ -e "$canonical" ] && canonical_ok=1
        fi
        if [ $canonical_ok -eq 0 ]; then
            fixmsg "NOT removing $path: canonical $canonical is missing — fix that first"
            return
        fi
    fi
    if $FIX; then
        rm -f "$path"
        acted "removed $path ($desc)"
    else
        fixmsg "rm -f $path  # $desc"
    fi
}

# fix_print <command> — never executed (e.g. sudo-requiring fixes)
fix_print() {
    fixmsg "$1"
}

# ============================================================================
# Group 1 — strong consolidation. We own where these live.
# ============================================================================

# --- claude (Claude Code native installer) ---
# Canonical: ~/.local/bin/claude.
# Non-canonical: ~/.bun/bin/claude (`bun add -g`), ~/.volta/bin/claude,
# ~/.volta/tools/image/node/*/bin/claude. llms_update.sh has the canonical
# purge logic; we mirror the detection here.
check_claude() {
    if ! command -v claude >/dev/null 2>&1 \
       && [ ! -e "$HOME/.bun/bin/claude" ] \
       && [ ! -e "$HOME/.volta/bin/claude" ] \
       && ! ls "$HOME/.volta/tools/image/node/"*"/bin/claude" >/dev/null 2>&1; then
        skip "claude: not installed"
        return
    fi

    local canon="$HOME/.local/bin/claude"
    local dups=0

    # Known non-canonical locations — only auto-remove when canonical exists.
    if [ -e "$HOME/.bun/bin/claude" ]; then
        warn "claude: duplicate at ~/.bun/bin/claude (bun-installed)"
        fix_remove "bun-installed claude" "$HOME/.bun/bin/claude" "$canon"
        dups=$((dups + 1))
    fi
    if [ -e "$HOME/.volta/bin/claude" ]; then
        warn "claude: duplicate at ~/.volta/bin/claude (volta-managed)"
        fix_remove "volta-managed claude" "$HOME/.volta/bin/claude" "$canon"
        dups=$((dups + 1))
    fi
    local vb
    for vb in "$HOME/.volta/tools/image/node/"*"/bin/claude"; do
        [ -e "$vb" ] || continue
        warn "claude: duplicate at $vb (volta node toolchain)"
        fix_remove "volta-node claude" "$vb" "$canon"
        dups=$((dups + 1))
    done

    if command -v claude >/dev/null 2>&1; then
        local resolved
        resolved=$(command -v claude)
        if [ "$resolved" = "$canon" ] && [ $dups -eq 0 ]; then
            ok "claude: $resolved"
        elif [ "$resolved" != "$canon" ]; then
            warn "claude: PATH-first at $resolved (expected $canon)"
            note "fix: cli_tools/llms_update.sh re-installs from claude.ai/install.sh"
        fi
    else
        fail "claude: only present in non-canonical locations"
        note "fix: cli_tools/llms_update.sh re-installs from claude.ai/install.sh"
    fi
}

# --- rustc / cargo (rustup-managed) ---
# Canonical: ~/.cargo/bin/{rustc,cargo}. Kitting script purges apt rustc/cargo.
check_rust() {
    local canon_rustc="$HOME/.cargo/bin/rustc"
    local canon_cargo="$HOME/.cargo/bin/cargo"

    if ! command -v rustc >/dev/null 2>&1 && [ ! -e "/usr/bin/rustc" ]; then
        skip "rustc: not installed"
    else
        if [ -e "/usr/bin/rustc" ]; then
            warn "rustc: apt-installed at /usr/bin/rustc (conflicts with rustup)"
            fix_print "sudo apt-get purge -y rustc cargo"
        fi
        if command -v rustc >/dev/null 2>&1; then
            local r
            r=$(command -v rustc)
            if [ "$r" = "$canon_rustc" ]; then
                ok "rustc: $r"
            else
                warn "rustc: PATH-first at $r (expected $canon_rustc)"
            fi
        fi
    fi
}

# --- cargo-canonical CLIs (bat, eza, rg, fd, delta) ---
# Phase 4 moved these from apt/brew to ~/.cargo/bin via cargo-binstall so
# the host keeps up with upstream feature releases. Canonical is always
# $HOME/.cargo/bin/<binary>; apt/brew copies are now duplicates and get
# flagged. On Linux, also flag the pre-Phase-4 /usr/local/bin/{bat,fd}
# symlinks to batcat/fdfind (see check_pre_phase4_symlinks below).
#
# check_cargo_tool <binary> <apt_pkg> <apt_bin> [brew_formula]
#   binary       — the command name on PATH (e.g. "rg", "delta")
#   apt_pkg      — apt package name (for the "apt purge" fix hint)
#   apt_bin      — file at /usr/bin/<X> on Linux (e.g. "batcat", "fdfind",
#                  or just <binary> when no rename — "eza", "delta")
#   brew_formula — brew formula name; defaults to apt_pkg (override when
#                  it differs, e.g. apt "fd-find" vs brew "fd")
check_cargo_tool() {
    local binary=$1
    local apt_pkg=$2
    local apt_bin=$3
    local brew_formula=${4:-$apt_pkg}
    local canon="$HOME/.cargo/bin/$binary"

    # Skip when not installed anywhere we'd look.
    if ! command -v "$binary" >/dev/null 2>&1 \
       && [ ! -e "$canon" ] \
       && { [ "$OS" = "Darwin" ] || [ ! -e "/usr/bin/$apt_bin" ]; } \
       && { [ "$OS" != "Darwin" ] || [ -z "$brew_prefix" ] || [ ! -e "$brew_prefix/bin/$binary" ]; }; then
        skip "$binary: not installed"
        return
    fi

    # Mac: brew copy is a Phase-4 leftover.
    if [ "$OS" = "Darwin" ] && [ -n "$brew_prefix" ] && [ -e "$brew_prefix/bin/$binary" ]; then
        warn "$binary: brew copy at $brew_prefix/bin/$binary (canonical is $canon)"
        fix_print "brew uninstall $brew_formula  # cargo binstall handles it now"
    fi

    # Linux: apt copy is a Phase-4 leftover (and batcat/fdfind are the
    # rename-renamed binaries that the old kit symlinked).
    if [ "$OS" != "Darwin" ] && [ -e "/usr/bin/$apt_bin" ]; then
        warn "$binary: apt copy at /usr/bin/$apt_bin (canonical is $canon)"
        fix_print "sudo apt-get purge -y $apt_pkg  # cargo binstall handles it now"
    fi

    # Resolution check.
    if command -v "$binary" >/dev/null 2>&1; then
        local r; r=$(command -v "$binary")
        if [ "$r" = "$canon" ]; then
            ok "$binary: $r"
        else
            warn "$binary: PATH-first at $r (expected $canon)"
        fi
    elif [ -e "$canon" ]; then
        # Canonical present but not resolvable — ~/.cargo/bin missing from PATH.
        warn "$binary: $canon exists but PATH doesn't include ~/.cargo/bin"
        note "fix: ensure 'source ~/.cargo/env' (or equivalent) lands in ~/.zshrc"
    fi
}

# --- pre-Phase-4 symlink cleanup (Linux only) ---
# Old kit created /usr/local/bin/{bat,fd} → /usr/bin/{batcat,fdfind} so
# the apt packages exposed the upstream-documented command names. After
# Phase 4 the apt packages are gone; the symlinks now point at deleted
# targets and shadow ~/.cargo/bin if PATH puts /usr/local/bin earlier.
check_pre_phase4_symlinks() {
    [ "$OS" = "Darwin" ] && return
    local stale
    for stale in /usr/local/bin/bat /usr/local/bin/fd; do
        if [ -L "$stale" ]; then
            warn "$stale: pre-Phase-4 symlink (Phase 4 puts bat/fd in ~/.cargo/bin)"
            fix_print "sudo rm $stale"
        fi
    done
}

# --- gh (GitHub CLI) ---
check_gh() {
    if ! command -v gh >/dev/null 2>&1 \
       && [ ! -e "/snap/bin/gh" ] \
       && [ ! -e "/home/linuxbrew/.linuxbrew/bin/gh" ]; then
        skip "gh: not installed"
        return
    fi
    local canon
    if [ "$OS" = "Darwin" ]; then
        canon="$brew_prefix/bin/gh"
    else
        canon="/usr/bin/gh"
    fi
    # Known non-canonical Linux locations
    if [ "$OS" != "Darwin" ]; then
        if [ -e "/snap/bin/gh" ]; then
            warn "gh: duplicate at /snap/bin/gh (snap-installed)"
            fix_print "sudo snap remove gh"
        fi
        # linuxbrew gh duplicate handled by the umbrella check_linuxbrew() below.
    fi
    if command -v gh >/dev/null 2>&1; then
        local r; r=$(command -v gh)
        if [ "$r" = "$canon" ]; then
            ok "gh: $r"
        else
            warn "gh: PATH-first at $r (expected $canon)"
        fi
    fi
}

# --- mise ---
check_mise() {
    if ! command -v mise >/dev/null 2>&1; then
        skip "mise: not installed"
        return
    fi
    local canon
    if [ "$OS" = "Darwin" ]; then
        canon="$brew_prefix/bin/mise"
    else
        canon="/usr/bin/mise"
    fi
    # linuxbrew mise duplicate handled by the umbrella check_linuxbrew() below.
    local r; r=$(command -v mise)
    if [ "$r" = "$canon" ]; then
        ok "mise: $r"
    else
        warn "mise: PATH-first at $r (expected $canon)"
    fi
}

# --- uv ---
check_uv() {
    if ! command -v uv >/dev/null 2>&1; then
        skip "uv: not installed"
        return
    fi
    local canon
    if [ "$OS" = "Darwin" ]; then
        canon="$brew_prefix/bin/uv"
    else
        canon="$HOME/.local/bin/uv"
    fi
    # linuxbrew uv duplicate handled by the umbrella check_linuxbrew() below.
    local r; r=$(command -v uv)
    if [ "$r" = "$canon" ]; then
        ok "uv: $r"
    else
        warn "uv: PATH-first at $r (expected $canon)"
    fi
}

# --- node (mise-managed) ---
check_node() {
    if ! command -v node >/dev/null 2>&1 \
       && [ ! -e "/usr/bin/node" ] \
       && [ ! -d "$HOME/.nvm" ] \
       && [ ! -d "$HOME/.volta" ]; then
        skip "node: not installed"
        return
    fi
    # Non-canonical: apt nodejs
    if [ "$OS" != "Darwin" ] && [ -e "/usr/bin/node" ]; then
        warn "node: apt nodejs at /usr/bin/node (conflicts with mise-managed node)"
        fix_print "sudo apt-get purge -y nodejs"
    fi
    # Non-canonical: nvm
    if [ -d "$HOME/.nvm" ] && ls "$HOME/.nvm/versions/node/"*"/bin/node" >/dev/null 2>&1; then
        warn "node: nvm-managed at ~/.nvm/versions/node/ (conflicts with mise)"
        fix_print "Disable nvm in your shell rc, or move it to ~/.zlocal if you really want it"
    fi
    # Non-canonical: volta
    if [ -d "$HOME/.volta/tools/image/node" ]; then
        warn "node: volta-managed at ~/.volta/tools/image/node/ (conflicts with mise)"
        fix_print "volta uninstall node  # or remove ~/.volta entirely"
    fi
    if command -v node >/dev/null 2>&1; then
        local r; r=$(command -v node)
        # mise activates via a shim; the shim or direct mise-installed path are both fine.
        case "$r" in
            "$HOME/.local/share/mise/"*|"$HOME/.local/share/mise/shims/node")
                ok "node: $r (mise)" ;;
            *)
                # Could be brew node on Mac or other — only warn if clearly non-mise.
                if [ "$OS" = "Darwin" ] && [ "$r" = "$brew_prefix/bin/node" ]; then
                    warn "node: brew-installed at $r (we prefer mise-managed for fleet uniformity)"
                else
                    warn "node: PATH-first at $r (expected mise-managed)"
                fi
                ;;
        esac
    fi
}

# ============================================================================
# Group 2 — warn-only. Common alternative installs may be intentional.
# ============================================================================

# --- linuxbrew (Linux only — deprecated) ---
# We've migrated off linuxbrew on Linux. Mac brew is canonical and not touched
# by this check. On Linux, /home/linuxbrew/.linuxbrew/bin/brew should not exist
# on newly kitted boxes; existing installs aren't auto-removed but should be.
check_linuxbrew() {
    [ "$OS" = "Darwin" ] && return  # Mac brew is canonical
    local brewbin="/home/linuxbrew/.linuxbrew/bin/brew"
    if [ ! -x "$brewbin" ]; then
        skip "linuxbrew: not installed (good — deprecated on Linux)"
        return
    fi
    warn "linuxbrew: /home/linuxbrew/.linuxbrew detected (deprecated on Linux)"
    note "apt + curl-pipe-sh cover all our tools — linuxbrew is parallel state."
    # Enumerate what's actually installed so the user can verify alternatives.
    local installed
    installed=$("$brewbin" list 2>/dev/null || true)
    if [ -n "$installed" ]; then
        local count
        count=$(echo "$installed" | wc -l)
        note "Currently installed via linuxbrew ($count package(s)):"
        echo "$installed" | head -15 | sed 's/^/         /'
        if [ "$count" -gt 15 ]; then
            note "         ... and $((count - 15)) more (run \`brew list\` to see all)"
        fi
    fi
    fix_print "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\""
    note "After uninstall, restart shells to drop /home/linuxbrew from PATH."
}

# --- ruby (Mac only) ---
check_ruby() {
    [ "$OS" = "Darwin" ] || { skip "ruby: warn-check skipped (Linux box; not our scope)"; return; }
    if ! command -v ruby >/dev/null 2>&1; then
        skip "ruby: not installed"
        return
    fi
    local canon="$brew_prefix/opt/ruby/bin/ruby"
    local r; r=$(command -v ruby)
    case "$r" in
        "$canon") ok "ruby: $r" ;;
        /usr/bin/ruby) warn "ruby: system /usr/bin/ruby ahead of brew Ruby; cocoapods etc. may break" ;;
        *) warn "ruby: PATH-first at $r (expected $canon)" ;;
    esac
}

# --- fvm/flutter mixing (warn-only) ---
check_flutter() {
    local has_direct=0 has_fvm=0
    [ -d "$HOME/flutter/bin" ] && has_direct=1
    [ -d "$HOME/fvm/default/bin" ] && has_fvm=1
    if [ $has_direct -eq 1 ] && [ $has_fvm -eq 1 ]; then
        warn "flutter: BOTH ~/flutter/bin (direct) and ~/fvm/default/bin (fvm) installed"
        note "PATH order matters — whichever is earlier wins. fvm is what kitting uses."
        fix_print "rm -rf ~/flutter  # if you want fvm to win cleanly"
    elif [ $has_direct -eq 1 ]; then
        skip "flutter: ~/flutter (direct install only, fvm absent)"
    elif [ $has_fvm -eq 1 ]; then
        skip "flutter: ~/fvm (fvm-managed only)"
    fi
}

# ============================================================================
# Run all checks
# ============================================================================

echo
echo "${B}=== Tool consistency audit ===${X}"
echo "${D}  Mode: $($FIX && echo "auto-fix" || echo "report only")${X}"
echo

check_claude
check_rust
# Cargo-canonical CLIs (Phase 4). Args: binary apt_pkg apt_bin [brew_formula]
check_cargo_tool bat   bat       batcat
check_cargo_tool eza   eza       eza
check_cargo_tool rg    ripgrep   rg
check_cargo_tool fd    fd-find   fdfind     fd
check_cargo_tool delta git-delta delta
check_pre_phase4_symlinks
check_gh
check_mise
check_uv
check_node
check_linuxbrew
check_ruby
check_flutter

echo
if [ $issues -eq 0 ]; then
    echo "${G}${B}✓ All clean.${X}"
else
    echo "${Y}${B}⚠ $issues issue(s) reported above.${X}"
    $FIX || echo "${D}  Re-run with --fix to auto-purge user-owned duplicates.${X}"
fi
echo

if $STRICT && [ $issues -gt 0 ]; then
    exit 1
fi
exit 0
