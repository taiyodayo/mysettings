# automated/ — declarative Ubuntu kitting

Ansible reimplementation of the Ubuntu shell scripts in this repo. The
original scripts at the repo root are unchanged and remain the bootstrap
path; this directory is what to use for repeatable / fleet runs.

Mac kitting is intentionally not here — it will live in a separate
directory later.

## Layout

```
automated/
├── ansible.cfg
├── inventory.yml
├── requirements.yml
├── Makefile
├── README.md
├── ubuntu_kitting.yml       # ≡ ubuntu/my_ubuntu_setup.sh
├── ubuntu_motd.yml          # ≡ ubuntu/ubuntu_motd_clean.sh
├── ubuntu_macbook_hw.yml    # ≡ ubuntu/ubuntu_on_macbook.sh
├── ubuntu_gui_tools.yml     # ≡ ubuntu/setup_gui_tools.sh
├── ubuntu_superclean.yml    # ≡ ubuntu/superclean_ubuntuserver/*
├── zsh_and_keys.yml         # ≡ common/setup_zsh_and_keys.sh (Linux)
└── llms_update.yml          # ≡ cli_tools/llms_update.sh
```

One self-contained playbook per original script. No roles, no nested
`tasks/main.yml` files — open the file and read it top-to-bottom.

## One-time bootstrap

From a fresh Ubuntu host with nothing pre-installed:

```bash
cd ~/mysettings/automated
make bootstrap     # installs pipx + ansible (per-user) + Galaxy collections
```

The bootstrap script is re-entrant — safe to re-run after a partial setup, or
to upgrade `ansible` to the latest pipx-distributed version. It:

- apt-installs `python3-venv`, `pipx`, `snapd`, `git`, `curl`,
  `ca-certificates`
- purges any apt-installed `ansible` (Ubuntu ships 2.10.x — too old for
  `community.general >= 8.0.0`)
- pipx-installs current `ansible` per-user under `~/.local/pipx/venvs/ansible`
- installs the Galaxy collections in `requirements.yml`

If `ansible` is already on PATH from another source, you can skip the bootstrap
and just install collections:

```bash
make collections
```

After bootstrap, open a fresh shell (pipx writes the PATH update to
`~/.bashrc` / `~/.zshrc`) — then `make kit` is ready.

## Running locally

The default inventory targets `localhost`, so SSH setup is not required.

```bash
make kit                       # full ubuntu kitting (sudo prompted)
make motd                      # strip motd ads
make zsh GH=taiyodayo          # zsh + import GitHub ed25519 key
make llms                      # update gemini / claude / codex
make audit                     # pre-reboot safety audit
```

`make help` lists every target. Add `EXTRA='--check --diff'` for a dry run:

```bash
make kit EXTRA='--check --diff'
```

## Running against a remote fleet

Edit `inventory.yml` to add hostnames (the file has a commented example),
then call `ansible-playbook` directly:

```bash
ansible-playbook ubuntu_kitting.yml
```

`mysettings_repo_dir` defaults to the parent of the playbook directory,
so the controller's local copy of this repo is what gets pushed to the
targets (for `_zshrc`, `certs/*.crt`, etc.).

## Variables you'll override

| Variable          | Where      | What it does                                        |
| ----------------- | ---------- | --------------------------------------------------- |
| `target_user`     | -e / inv   | Who owns brew / mise / uv / `~/.zshrc` (default: invoking user) |
| `github_username` | -e         | GitHub user whose ed25519 key gets authorised       |
| `apply_purge`     | -e         | Actually delete in `--tags purge` (default: false)  |

## Things kept imperative (and why)

A handful of upstream installers stayed as shell blocks; there's no
declarative module for them and rewriting inline would lose upstream
updates:

- **IMEI installer** — builds ImageMagick 7 against pinned ghostscript.
- **claude native installer** (`install.sh | bash`).
- **claude shim purge** — walking `~/.bun/bin`, `~/.volta/tools/image/node/*`,
  uninstalling via each node's npm. One commented shell block.

## Things intentionally NOT automated

(Mirrors the original scripts.)

- Reboot after `make macbook-hw` (so the new initramfs takes effect).
- `chsh` won't take effect until you log out and back in.
