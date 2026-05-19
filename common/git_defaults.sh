#!/usr/bin/env bash
# Apply the lab's standard git global defaults.
# Identical recipe on Mac and Linux. Runs as the target user.

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: git_defaults.sh must run as the target user, not root." >&2
    exit 1
fi

git config --global user.name  "taiyo@$(hostname) default"
git config --global user.email "taiyodayo@gmail.com"
# Cache HTTPS creds in memory for 15 min (default). Prefer this over
# `store` so an accidental PAT paste during `git clone https://...` never
# hits disk. SSH-based auth (git@github.com:...) doesn't use the helper.
git config --global credential.helper cache
# Auto-prune remote-deleted branch refs / tags on every fetch.
git config --global fetch.prune true
git config --global fetch.pruneTags true
# `git pull` = rebase, not merge — keeps history linear.
git config --global pull.rebase true
# `git sync` = fetch + prune remote-deleted refs + drop local branches whose
# upstream is gone. Depends on git-trim (cargo-installed elsewhere).
git config --global alias.sync '!git fetch --all --prune && git trim --no-confirm'
