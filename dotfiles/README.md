# dotfiles/ — chezmoi source directory

This directory is the [chezmoi](https://chezmoi.io) source for files that land in `~/`. Today (post-PR 1, pre-PR 4) it is **opt-in**: existing kitted machines keep using `_zshrc` + the imperative appends in the kitting scripts. Run `../migrate_to_chezmoi.sh` on a machine to switch it over.

## Layout

| Source file (here)        | Deployed as       | Notes |
|---------------------------|-------------------|-------|
| `dot_zshrc.tmpl`          | `~/.zshrc`        | absorbs all 8 imperative kitting-script appends as runtime conditionals |
| `dot_p10k.zsh`            | `~/.p10k.zsh`     | verbatim copy of `_p10k.zsh` (no template needed) |
| `dot_gitconfig.tmpl`      | `~/.gitconfig`    | hostname is templated via `.chezmoi.hostname` |
| `dot_zprofile.tmpl`       | `~/.zprofile`     | linuxbrew shellenv on Ubuntu, empty on Mac |

Filename convention: `dot_foo` → `~/.foo`; `.tmpl` suffix marks files that go through chezmoi's Go template engine.

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

## Secrets / tokens

**Do not commit secrets.** This source directory is in `~/mysettings/`, which is a public-ish git repo.

If `chezmoi add ~/.zshrc` captures a token an installer wrote, the token will be in your next commit's diff — **review with `git diff dotfiles/` before committing.** Same applies to `~/.gitconfig` if it ever picks up an HTTPS PAT.

If you eventually need to commit a secret (an SSH config snippet, an API token), set up chezmoi's [age encryption](https://www.chezmoi.io/user-guide/encryption/age/) and use the `encrypted_` prefix on the source filename. Not configured today.

## Why a separate `dotfiles/` subdirectory?

chezmoi's default source location is `~/.local/share/chezmoi/`. We override that via `~/.config/chezmoi/chezmoi.toml` (written by `migrate_to_chezmoi.sh`) so chezmoi reads from `~/mysettings/dotfiles/`. Result: one repo for everything (kitting scripts, ansible playbooks, certs, dotfile templates), one `git pull`, one PR queue.

Files inside this directory that **don't** start with `dot_`, `private_`, `run_`, `executable_`, `symlink_`, or other chezmoi prefixes (like this README) are silently ignored by chezmoi and never deployed.
