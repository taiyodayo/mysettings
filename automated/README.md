> Tool installation/update ownership changed: see [mise migration](../docs/mise.md).
> Historical installer descriptions below are superseded by that guide.

# automated/ — declarative kitting (cross-platform)

Ansible reimplementation of the shell kit scripts in this repo. The
original scripts at the repo root are unchanged and remain the bootstrap
path; this directory is what to use for repeatable / fleet runs.

As of Phase 6, this directory drives both Ubuntu and Mac kits via the
`kitting.yml` dispatcher.

## Layout

```
automated/
├── ansible.cfg
├── inventory.yml
├── requirements.yml
├── Makefile
├── README.md
├── kitting.yml              # cross-platform dispatcher (calls one of ↓)
├── ubuntu_kitting.yml       # ≡ ubuntu/my_ubuntu_setup.sh
├── mac_kitting.yml          # ≡ mac/setup_cli_tools.sh + setup_gui_apps.sh + brew_tidyverse.sh
│                            #   (minus mas/Xcode/AppleScript — those stay in setup_mailab_mac.sh)
├── ubuntu_motd.yml          # ≡ ubuntu/ubuntu_motd_clean.sh
├── ubuntu_macbook_hw.yml    # ≡ ubuntu/ubuntu_on_macbook.sh
├── ubuntu_gui_tools.yml     # ≡ ubuntu/setup_gui_tools.sh
├── ubuntu_superclean.yml    # ≡ ubuntu/superclean_ubuntuserver/*
├── zsh_and_keys.yml         # ≡ common/setup_zsh_and_keys.sh (Linux)
├── llms_update.yml          # ≡ cli_tools/llms_update.sh
├── group_vars/              # all.yml + linux.yml + darwin.yml (loaded via group_by in kitting.yml)
└── tasks/                   # common_*.yml — shared per-tool tasks (mise/dart/bun/node/fvm/git)
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
make kitting                   # cross-platform kitting (auto-detects OS)
make kit                       # Ubuntu-only kitting (back-compat alias)
make mac-kit                   # Mac-only kitting
make motd                      # strip motd ads (Ubuntu)
make zsh GH=taiyodayo          # zsh + import GitHub ed25519 key (Ubuntu)
make llms                      # self-managed agent notice; no updates
make audit                     # pre-reboot safety audit (Ubuntu)
```

`make help` lists every target. Add `EXTRA='--check --diff'` for a dry run:

```bash
make kit EXTRA='--check --diff'
```

## Remote Ubuntu from your workstation

For a USB-installed **Ubuntu 22.04+** machine, prepare an existing non-root account,
sshd and your public key during installation. That account must have sudo privileges.
No Ansible or Python installation is required on the target before starting.
Keep Ansible on the workstation under its existing installation owner (on macOS:
`brew install ansible`). The baseline uses only built-in Ansible modules.

Run from the repository root:

```sh
ssh alice@192.168.1.50                       # verify the host fingerprint once
./kit-server alice@192.168.1.50 -K --check    # read-only SSH/Ubuntu/sudo preflight
./kit-server alice@192.168.1.50 -K            # apply
```

Replace the username/address with your known SSH account and host. `-K` prompts for
its sudo password; omit it for passwordless sudo. SSH aliases/agent configuration
are honored. Use `--port 2222` or `--identity ~/.ssh/server_key` when needed.
Host-key checking remains enabled; the launcher never edits the localhost inventory.

The default kit installs missing distribution Python, native build prerequisites,
and apt-owned mise. It checks out the selected commit into the SSH user's
`~/mysettings`, applies the locked `ubuntu-server` profile as that user, and links
mise configuration back to that checkout. It backs up an existing shell rc before
adding one activation block (bash or zsh), and verifies runtime commands explicitly.
It does not change SSH keys, firewall rules, application services or reboot.
Internet access to Ubuntu package sources, GitHub and tool download hosts is required.

`--check` is deliberately **preflight only**, even with `--lab`: it checks the OS,
login and sudo without installing Python or downloading tools. It is not a full
simulation of package/runtime changes. Applying repeatedly reuses installed tools
and refuses dirty checkouts, history rewinds and divergent histories.

By default the target receives the workstation's **committed HEAD**, resolved to an
exact SHA. Publish that commit to origin first; uncommitted edits are not deployed.
`--ref main` or `--ref COMMIT` selects a different locally known, published revision.
The controller executes its local playbooks, so use a reviewed checkout there too.
The remote tracking branch supports the usual `cli_tools/machine sync`; alternatively
rerun `kit-server` from your updated workstation checkout. Locks are not advanced by
kitting. Application deployment, pinned service runtimes and restarts remain separate.
Existing machines should follow [migration/rollback](../docs/mise.md) first; retain
old runtime installations and review legacy shell initialization before using this kit.

For the broader existing lab recipe, explicitly opt in:

```sh
ansible-galaxy collection install -r automated/requirements.yml
./kit-server alice@192.168.1.50 -K --lab
```

Review `ubuntu_kitting.yml` first: this also upgrades apt packages, changes system
settings and certificate trust, installs R/r2u and Docker, and starts/restarts services
including Docker/monitoring. It is not necessary for the minimal server tool setup.
Remote execution paths are resolved on the target; local copy sources remain in the
controller checkout. Codex and Claude remain self-managed.

Verification: shell syntax/ShellCheck, both playbook syntax checks and stubbed launcher
argument/inventory checks on macOS. Actual SSH bootstrap, Ubuntu package installation,
second-run idempotence and the optional lab recipe still require a disposable Ubuntu
host; no remote target was supplied or contacted.

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
Codex and Claude installation, versions, updates and cleanup are intentionally unmanaged by this repository.
The historical `llms` entry point only prints that ownership policy.

## Things intentionally NOT automated

(Mirrors the original scripts.)

- Reboot after `make macbook-hw` (so the new initramfs takes effect).
- `chsh` won't take effect until you log out and back in.
