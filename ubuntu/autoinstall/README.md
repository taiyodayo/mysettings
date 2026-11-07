# Minimal Ubuntu Server 26.04 USB setup

This template prepares a small SSH/Ansible-ready server. It installs OpenSSH Server,
your public key, Avahi for local hostname discovery, and minimal Ansible prerequisites.
Tool installation remains a separate workstation-driven `kit-server` step.

1. Prepare an Ubuntu **Server 26.04 LTS** installation USB.
2. Make a local copy of [autoinstall.yaml](autoinstall.yaml). Replace the entire
   example `ssh-ed25519 REPLACE_WITH_YOUR_PUBLIC_KEY` string with your actual public
   key (for example the contents of `~/.ssh/id_ed25519.pub`). Do not use a private key.
3. If the installer partition is writable, copy your edited file to its root:
   **the same directory as `casper/`**, named exactly `autoinstall.yaml`.
   A separate arbitrary USB partition or the root directory holding a Ventoy ISO
   is not equivalent to the installation-media root.
4. Boot the USB. Select **Ubuntu Server (minimized)** at the source screen, then
   choose networking, the destination disk and the account/hostname interactively.
   Set an account password for local login and sudo; SSH password login is disabled.
5. Complete installation and reboot into the installed system.

A USB written by raw ISO flashing commonly has a read-only installer filesystem.
In that case, simply copying this file to its root will not work. Use Canonical's
[NoCloud delivery method](https://canonical-subiquity.readthedocs-hosted.com/en/latest/howto/autoinstall-quickstart.html)
(with `#cloud-config` followed by this YAML as `user-data`, plus `meta-data`, supplied
as a NoCloud seed), or prepare installation media whose contents are writable.
The exact USB preparation steps depend on the writer you use. See
[Canonical's supported locations and delivery methods](https://canonical-subiquity.readthedocs-hosted.com/en/latest/tutorial/providing-autoinstall.html).

The additional packages need access to an Ubuntu package mirror during installation.
Avahi advertises the chosen hostname on the local network. `.local` resolution also
requires mDNS support on the workstation and a network that permits multicast; use
the server's IP address if discovery is unavailable.

From your workstation's updated `mysettings` checkout:

```sh
ssh youruser@hostname.local                          # verify the host key
./kit-server youruser@hostname.local -K --check       # read-only preflight
./kit-server youruser@hostname.local -K               # apply locked server tools
```

Omit `-K` for passwordless sudo. See [remote kitting](../../automated/README.md#remote-ubuntu-from-your-workstation)
for prerequisites and scope. The USB alone does not install mise, runtimes, Docker
or application services. The wider lab recipe remains a separate `--lab` opt-in.

The template follows the current [Subiquity configuration reference](https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html).
Local validation checks YAML structure and required fields. It has **not been
boot-tested against a 26.04 ISO**; validate first on a disposable VM or machine.
