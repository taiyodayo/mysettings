#!/usr/bin/env bash
# Privileged installer for r-cran-* packages. Invoked via sudo by
# members of the r-installers group, granted NOPASSWD on this wrapper
# (and ONLY this wrapper) by /etc/sudoers.d/r-installers.
#
# Strict whitelist: every argument must match r-cran-[a-zA-Z0-9.+-]+ —
# no globs, no paths, no other apt subcommands. Removal is intentionally
# not supported: a user could `apt remove r-cran-tidyverse` and break R
# for the whole lab. Removal is admin-only via plain sudo.
#
# Deployed to /usr/local/bin/r-install by ubuntu/my_ubuntu_setup.sh.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "r-install: must be run via sudo" >&2
    exit 1
fi

if [ "$#" -lt 1 ]; then
    echo "Usage: sudo r-install <r-cran-package> [...]" >&2
    exit 64
fi

for pkg in "$@"; do
    if [[ ! "$pkg" =~ ^r-cran-[a-zA-Z0-9.+-]+$ ]]; then
        echo "r-install: refusing non-r-cran package name: $pkg" >&2
        exit 1
    fi
done

exec /usr/bin/apt-get install -y --no-install-recommends "$@"
