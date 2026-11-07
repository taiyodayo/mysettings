# mysettings

Personal machine configuration for macOS workstations, Omarchy workstations and Ubuntu servers.
Developer tools are declared in `toolchain/`; application dependencies stay in their projects.
Codex and Claude are self-managed and excluded from repository installation, pinning, updates and cleanup.

```sh
# Select ONE profile in this checkout (untracked machine choice).
./cli_tools/machine select macos-workstation
# Alternatives: omarchy-workstation / ubuntu-server
./cli_tools/machine native       # native prerequisites; explicit system changes
./cli_tools/machine setup        # install locked tools, back up and link mise config
```

Existing machines: start with `machine plan` and follow the [migration and rollback guide](docs/mise.md)
before switching shell initialization. Setup does not overwrite shell files, delete old tools,
change SSH keys, deploy services or restart applications. Minimum mise: **2026.11.0**. Workstation artifacts currently target Apple Silicon Mac and x86_64 Linux;
see the guide for other architecture limitations.

Normally run **`./cli_tools/machine sync`** to fast-forward a clean checkout and apply its locks.
To advance personal tools within their declared policies, run **`./cli_tools/machine update-tools`**,
review the lock changes and commit them. Projects inheriting defaults can be affected.
On Omarchy, **`machine update-system`** already includes mise updates; do not run both update paths.

| Command | Changes |
| --- | --- |
| `machine plan` | Shows selected configuration and missing installations |
| `machine apply` | Installs locked tools, no config linking or dependency updates |
| `machine setup [profile]` | Apply, then back up/link `~/.config/mise` to this checkout |
| `machine doctor` | Read-only paths, configuration and missing tools |
| `machine update-system` | Homebrew / Ubuntu apt / complete Omarchy maintenance |
| `machine upgrade-versions TOOL@VERSION` | Deliberately changes the named policy and its lock |
| `machine cleanup` | Preview only; never deletes installations |
| `machine lab` | Syncs the opt-in Python 3.13 lab environment from `packages/lab-python/uv.lock` |

[Ownership, project migration, server execution, exceptions and verification](docs/mise.md)

`setup_mailab_mac.sh` and `setup_mailab_ubuntu.sh` now alias tool setup. Broad lab provisioning
(R, Docker, GUI applications, SSH keys, system preferences) remains opt-in in `mac/`, `ubuntu/`
and `automated/`; it is not ordinary tool maintenance. Review these older recipes before running:
some intentionally change services, package sources and user access. No Omarchy machine should
run an Ubuntu recipe. The existing chezmoi source is `dotfiles/`; `_zshrc` mirrors its zsh template.

From your workstation, kit a minimal Ubuntu server with an existing SSH account and sudo access:

```sh
ssh alice@192.168.1.50                 # verify the host key once
./kit-server alice@192.168.1.50 -K --check  # read-only Ubuntu/SSH/sudo preflight
./kit-server alice@192.168.1.50 -K          # install the locked Ubuntu server setup
```

Replace `alice` and the address; omit `-K` for passwordless sudo. Requires workstation Ansible.
The launcher bootstraps missing Python, deploys this checkout's committed revision, installs
native prerequisites/mise/tools, and adds a backed-up shell activation block. Re-run the same
command to apply a newer published commit. [Remote setup and scope](automated/README.md#remote-ubuntu-from-your-workstation).

For the preceding USB installation step, use the [Ubuntu Server 26.04 minimal
autoinstall template](ubuntu/autoinstall/README.md). It installs SSH, your public key,
Avahi, Ansible prerequisites and third-party drivers. Disk and account selection stay
interactive; the chosen disk receives a full-size Btrfs root on LVM.
