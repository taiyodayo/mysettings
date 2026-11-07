# Ubuntu Server 26.04: disk and account prompts only

The template installs minimal Ubuntu Server with SSH, Avahi and system Python for
Ansible. It asks which disk to erase, then uses Ubuntu's account screen for username,
local/sudo password and hostname. `taiyo` is prefilled; choose a unique hostname.
The normal name/password-confirmation fields are still part of that native screen.

## Prepare the USB

1. Use an Ubuntu **Server 26.04 LTS** ISO and boot in **UEFI mode**. This layout
   deliberately does not implement legacy BIOS boot.
2. Copy both [autoinstall.yaml](autoinstall.yaml) and [select-disk.py](select-disk.py)
   to the writable installer root, **beside `casper/`**. Replace the entire example
   SSH public key with your real `.pub` key. Never copy a private key.
3. To skip Ubuntu's initial autoinstall confirmation, add `autoinstall` to the
   installer's kernel command line in the USB boot entry. This does not skip the
   disk selector or account screen. Without it, expect an additional confirmation.
4. Boot with Ethernet connected. Select the target disk by its displayed path,
   capacity, model and serial. **That disk will be erased completely.** There is no
   default disk; `q` aborts. Then enter your account details in the installer.
5. After installation the machine powers off. Remove the USB and power it on.

The disk selector runs on a free virtual terminal and returns to the installer. It modifies
only the live `/autoinstall.yaml`; Subiquity/curtin performs the actual formatting.
It excludes USB disks, read-only disks, disks with mounted descendants and disks
smaller than 16 GiB. This profile targets internal/virtual disks, not USB-attached
installation targets. It stops if the public-key placeholder was not replaced.

A raw-flashed ISO commonly has a read-only installer filesystem, so copying files
to its root is not possible. Prepare writable installation media or a remastered
ISO containing both files. The root holding a Ventoy ISO is not the installer root.
Canonical also supports [NoCloud delivery](https://canonical-subiquity.readthedocs-hosted.com/en/latest/howto/autoinstall-quickstart.html),
but this profile's helper path `/cdrom/select-disk.py` must still be made available
(or adapted to its actual location); a seed containing only the YAML is insufficient.
See [supported delivery methods](https://canonical-subiquity.readthedocs-hosted.com/en/latest/tutorial/providing-autoinstall.html)
and [the boot confirmation](https://canonical-subiquity.readthedocs-hosted.com/en/latest/explanation/zero-touch-autoinstall.html).

## Declared machine defaults

| Area | Configuration |
| --- | --- |
| System | Minimal Ubuntu Server, English/US keyboard, Asia/Tokyo timezone |
| Updates | Refresh the stable installer; install security and regular 26.04 updates before completion |
| Drivers | Install Ubuntu-recommended third-party drivers when available, including detected GPU drivers |
| Network | IPv4 DHCP, IPv6 DHCP and router advertisements on Ethernet `en*`/`eth*` interfaces |
| Access | SSH public keys only for all users; root SSH disabled; local login/sudo use the entered password |
| Packages | OpenSSH Server, Avahi, sudo, Python 3/python3-apt, CA certificates, Btrfs/LVM tools |
| Extras | No extra snaps, no Ubuntu Pro attachment, no project dependencies |
| Completion | Power off for USB removal |

Connect the intended Ethernet NIC. Unplugged ports are optional and do not hold up
boot; if several ports are connected, each can acquire an address. Wi-Fi, unusual
NIC names, VLANs and static addresses need an explicit Netplan adjustment. IPv6
addresses depend on the router's advertisements/DHCP service. Avahi supplies
`hostname.local` on networks allowing mDNS; otherwise use the IP address.

There is **no shared default password**. The `!` in the template is a locked
placeholder; the interactive account screen supplies the chosen password. SSH
password and keyboard-interactive authentication are disabled machine-wide by an
sshd drop-in, irrespective of the local account password. Run `passwd` later if you
want to change it. This does not disable local console passwords or make sudo
passwordless. No credential is committed to the repository.

GPU driver installation may require Secure Boot/MOK enrollment, adding a firmware
prompt. Driver availability depends on the GPU and Ubuntu's repositories. PyTorch,
CUDA runtime wheels and project dependencies belong in the project's uv environment;
this USB does not install the CUDA toolkit or PyTorch globally.

## Disk layout

The selected disk is reformatted as GPT:

| Allocation | Filesystem/use |
| --- | --- |
| 1 GiB | FAT32 EFI system partition, mounted at `/boot/efi` |
| 2 GiB | ext4 `/boot` for straightforward bootloader support |
| Remaining disk | LVM physical volume and `ubuntu-vg` volume group |
| All available VG space | One logical volume `root`, Btrfs mounted at `/` |

There is one filesystem for regular data: `/` includes `/home`, `/var` and everything
else. Boot partitions are separate. Both the LVM partition and root LV fill the
remaining space (`size: -1`); Ubuntu's default scaled/100-GiB root limit is not used.
There is no encryption, swapfile, swap partition, snapshot automation or separate
Btrfs subvolume layout. Swap on Btrfs requires deliberate setup later if wanted.

The native guided storage screen generates its own layout, so it is not used to
select a disk for this custom Btrfs recipe. The small selector only chooses the disk;
all storage actions remain declared in YAML. The minimal source ID must exist in
the ISO's `casper/install-sources.yaml`.

## After installation

From your workstation's updated `mysettings` checkout:

```sh
ssh taiyo@hostname.local                         # verify the host key
./kit-server taiyo@hostname.local -K --check      # read-only preflight
./kit-server taiyo@hostname.local -K              # apply locked server tools
```

See [remote kitting](../../automated/README.md#remote-ubuntu-from-your-workstation).
The broader lab recipe remains a separate `--lab` opt-in. Do not assume older
R/Docker repository recipes support 26.04 without checking their package sources.

## Verification and references

Run the disk-selector tests without touching any disks:

```sh
python3 -m unittest discover -s ubuntu/autoinstall -p 'test_*.py'
```

Tests cover disk exclusions, explicit selection/cancellation, key-placeholder
rejection and config substitution. The template passes the upstream Subiquity
26.04.1 JSON Schema; embedded shell syntax and storage references were also checked
locally. This profile has **not been boot-tested on a 26.04 ISO**. Terminal switching,
installer identity defaults, Btrfs/LVM boot, GPU drivers and a second physical NIC
still need a disposable VM/machine trial before using it for real installations.

References: [Subiquity configuration](https://canonical-subiquity.readthedocs-hosted.com/en/latest/reference/autoinstall-reference.html),
[curtin storage actions](https://curtin.readthedocs.io/en/latest/topics/storage.html),
[Netplan network settings](https://netplan.readthedocs.io/en/stable/netplan-yaml/).
