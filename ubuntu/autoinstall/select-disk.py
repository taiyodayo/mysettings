#!/usr/bin/env python3
"""Installer-only disk prompt; edits the live YAML, never formats a disk itself."""
import json
from pathlib import Path
import re
import subprocess
import sys

TOKEN = '"__SELECT_INSTALL_DISK__"'


def descendants(device):
    yield device
    for child in device.get("children", []):
        yield from descendants(child)


def eligible_disks(devices):
    """Exclude USB/install media, read-only disks, and any mounted descendants."""
    return [
        disk for disk in devices
        if disk.get("type") == "disk"
        and disk.get("tran") != "usb"
        and not disk.get("ro")
        and int(disk.get("size", 0)) >= 16 * 1024**3
        and not any(any(node.get("mountpoints") or []) for node in descendants(disk))
    ]


def select_disk(disks, ask=input):
    if not disks:
        raise ValueError("No eligible unmounted, non-USB disk of at least 16 GiB found.")
    print("\nUbuntu Server: erase ONE disk and install Btrfs / on LVM.")
    print("The selected disk's existing partitions and data will be erased.")
    for number, disk in enumerate(disks, 1):
        gib = int(disk["size"]) / 1024**3
        print(f"{number}: {disk['name']} | {gib:.1f} GiB | "
              f"{disk.get('model') or '?'} | serial {disk.get('serial') or '?'}")
    while True:
        answer = ask("Disk number to ERASE (q aborts; no default): ").strip()
        if answer.lower() == "q":
            raise ValueError("Installation cancelled; no disk selected.")
        if answer.isascii() and answer.isdecimal() and 1 <= int(answer) <= len(disks):
            return disks[int(answer) - 1]["name"]
        print("Enter one of the displayed disk numbers, or q.")


def render_config(config, disk):
    if config.count(TOKEN) != 1:
        raise ValueError("Expected exactly one disk-selection placeholder in /autoinstall.yaml.")
    if "REPLACE_WITH_YOUR_PUBLIC_KEY" in config:
        raise ValueError("Replace the SSH public-key placeholder on the USB before installing.")
    if not re.fullmatch(r"/dev/[A-Za-z0-9_.+-]+", disk):
        raise ValueError("Unexpected disk path; refusing to change installer configuration.")
    return config.replace(TOKEN, json.dumps(disk))


def main():
    if not Path("/sys/firmware/efi").is_dir():
        raise ValueError("Boot this installer in UEFI mode; legacy BIOS is not supported by this layout.")
    path = Path("/autoinstall.yaml")
    config = path.read_text()
    # Validate before asking for a disk. This does not write anything.
    render_config(config, "/dev/validation-only")
    subprocess.run(["udevadm", "settle"], check=True)
    result = subprocess.run(
        ["lsblk", "--json", "--bytes", "--paths", "--output",
         "NAME,TYPE,SIZE,MODEL,SERIAL,RO,TRAN,MOUNTPOINTS"],
        check=True, capture_output=True, text=True,
    )
    disks = eligible_disks(json.loads(result.stdout)["blockdevices"])
    disk = select_disk(disks)
    path.write_text(render_config(config, disk))
    print(f"Selected {disk}. Returning to the installer for account/hostname setup.")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError, EOFError, KeyboardInterrupt) as exc:
        print(f"\nSTOP: {exc}", file=sys.stderr)
        try:
            input("Press Enter to return to the installer error screen.")
        except (EOFError, KeyboardInterrupt):
            pass
        sys.exit(1)
