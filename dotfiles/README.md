# dotfiles/ — chezmoi source directory

This directory is the [chezmoi](https://chezmoi.io) source for files that land in `~/`. Today (post-PR 1, pre-PR 4) it is **opt-in**: existing kitted machines keep using `_zshrc` + the imperative appends in the kitting scripts. Run `../migrate_to_chezmoi.sh` on a machine to switch it over.

## Layout

| Source file (here)                                       | Deploys to / runs as                       | Notes |
|----------------------------------------------------------|--------------------------------------------|-------|
| `dot_zshrc.tmpl`                                         | `~/.zshrc`                                 | absorbs all 8 imperative kitting-script appends as runtime conditionals. Cross-platform Flutter/bun blocks plus Mac-only block for GNU coreutils, dart pub, Android SDK, p313 venv |
| `dot_p10k.zsh`                                           | `~/.p10k.zsh`                              | verbatim copy of `_p10k.zsh` (no template needed) |
| `modify_dot_gitconfig.tmpl`                              | `~/.gitconfig`                             | **surgical** — uses `git config -f` to set canonical keys only, preserves everything else (e.g. `gh auth setup-git`'s per-host credential helpers stay intact) |
| `dot_zprofile.tmpl`                                      | `~/.zprofile`                              | brew shellenv on Mac (and tolerates existing linuxbrew on Linux during deprecation) |
| `run_onchange_install-rustup-and-cargo-tools.sh`         | runs whenever its content changes          | installs/updates rustup (curl-pipe-sh), then `cargo install --locked git-trim`. Add more cargo CLIs here = next apply installs them |
| `run_onchange_install-uv.sh`                             | runs whenever its content changes          | installs/updates uv via astral.sh installer. No-op when uv was installed via package manager |

Filename conventions:

- `dot_foo` → `~/.foo`
- `.tmpl` suffix → file goes through chezmoi's Go template engine (`{{ if eq .chezmoi.os "darwin" }}` etc.)
- `modify_` prefix → executable that takes current target file on stdin, emits new content on stdout. Used for partial edits (so we can preserve user-added keys in `~/.gitconfig`).
- `run_once_<name>` → executable that runs once per content hash. chezmoi tracks state and skips if hash unchanged on re-apply.
- `run_onchange_<name>` → executable that re-runs whenever the file's content hash changes. Edit the script (e.g. add a cargo CLI) and next apply runs it.

## Daily workflow

```bash
chezmoi edit ~/.zshrc       # opens dotfiles/dot_zshrc.tmpl in $EDITOR
chezmoi diff                # preview pending changes on this machine
chezmoi apply               # deploy
cd ~/mysettings && git add dotfiles/ && git commit -m "..."
```

To capture changes that an installer (or you) made directly to `~/.zshrc`:

```bash
chezmoi add ~/.zshrc        # pulls current ~/.zshrc back into dotfiles/dot_zshrc
git diff dotfiles/          # review what got captured before committing
```

## Where to put machine-specific or installer-added content

`chezmoi apply` overwrites the managed files. Anything you want to **persist across applies** goes in one of:

- **`~/.zlocal`** — sourced near the end of `~/.zshrc`. Already conventional in this repo. Use for per-machine env vars, host-specific aliases.
- **`~/.zshrc.local`** — sourced last. Use for installer-added blocks (`conda init zsh`, `gh auth setup-git`, etc.) that you want to keep instead of re-running every apply.

Neither file is touched by chezmoi.

## ~/.p10k.zsh policy

The `dot_p10k.zsh` template is **authoritative** — the canonical lab prompt style lives in the repo. `chezmoi apply` intentionally overwrites any local `p10k configure` customizations to keep the prompt uniform across machines.

If you change the prompt style and want it propagated to all machines:

```bash
p10k configure              # tweak it on one machine
chezmoi add ~/.p10k.zsh     # capture into dotfiles/dot_p10k.zsh
cd ~/mysettings && git diff dotfiles/dot_p10k.zsh   # review
git add dotfiles/ && git commit && git push
# Other machines: git pull && chezmoi apply
```

If you want a one-off per-machine prompt tweak: put it in `~/.zlocal` (which is sourced AFTER `~/.p10k.zsh` in `~/.zshrc` so overrides take effect).

`migrate_to_chezmoi.sh` always backs up the existing `~/.p10k.zsh` to `~/.dotfiles_backup.<ts>/.p10k.zsh` before applying, so recovery is `cp -a ~/.dotfiles_backup.<ts>/.p10k.zsh ~/.p10k.zsh`.

## Secrets / tokens

**Do not commit secrets.** This source directory is in `~/mysettings/`, which is a public-ish git repo.

If `chezmoi add ~/.zshrc` captures a token an installer wrote, the token will be in your next commit's diff — **review with `git diff dotfiles/` before committing.** Same applies to `~/.gitconfig` if it ever picks up an HTTPS PAT.

If you eventually need to commit a secret (an SSH config snippet, an API token), set up chezmoi's [age encryption](https://www.chezmoi.io/user-guide/encryption/age/) and use the `encrypted_` prefix on the source filename. Not configured today.

## Why a separate `dotfiles/` subdirectory?

chezmoi's default source location is `~/.local/share/chezmoi/`. We override that via `~/.config/chezmoi/chezmoi.toml` (written by `migrate_to_chezmoi.sh`) so chezmoi reads from `~/mysettings/dotfiles/`. Result: one repo for everything (kitting scripts, ansible playbooks, certs, dotfile templates), one `git pull`, one PR queue.

Files inside this directory that **don't** start with `dot_`, `private_`, `run_`, `executable_`, `symlink_`, or other chezmoi prefixes (like this README) are silently ignored by chezmoi and never deployed.
