#!/usr/bin/env bash
# Cleanup script for systems previously kitted with the old CRAN-source R
# install (pre-r2u version of ubuntu/my_ubuntu_setup.sh).
#
# Run this BEFORE re-running my_ubuntu_setup.sh so the new r2u-based
# section installs cleanly without colliding with the legacy install.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" >&2
    exit 1
fi

cat <<'EOF'
=== 旧 CRAN ソースインストール R をクリーンアップ ===
This will:
  1. Remove the old CRAN apt source list + Marutter signing key
  2. Drop the legacy apt-key entry (E084DAB9)
  3. Purge r-base / r-base-core / r-base-dev
  4. Delete source-built R packages under /usr/local/lib/R/
  5. List (but NOT remove) the heavy tidyverse build-deps so you can
     decide manually.
After this, re-run ubuntu/my_ubuntu_setup.sh to install R via r2u.

EOF

read -r -p "Continue? [y/N] " -n 1 -r reply
echo
[[ $reply =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

pkg_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

# 1. Drop the old CRAN source list(s) — match by URL so we don't depend on filename.
echo "--- Removing old CRAN apt source lists..."
shopt -s nullglob
for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
    if grep -q 'cloud\.r-project\.org' "$f" 2>/dev/null; then
        echo "  rm $f"
        rm -f "$f"
    fi
done
shopt -u nullglob

# 2. Drop the Marutter signing key (both possible filenames the old script left).
echo "--- Removing Marutter signing key..."
rm -f /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc \
      /etc/apt/trusted.gpg.d/cran_ubuntu_key.gpg

# 3. Drop the deprecated apt-key entry. apt-key is itself deprecated but still
#    works for cleanup of legacy entries on current Ubuntu LTS.
if command -v apt-key >/dev/null 2>&1; then
    echo "--- Dropping legacy apt-key entry E084DAB9..."
    apt-key del E084DAB9 2>/dev/null || true
fi

apt-get update || true

# 4. Purge R from the old repo. The new setup script will reinstall from r2u.
echo "--- Purging r-base / r-base-core / r-base-dev..."
apt-get purge -y r-base r-base-core r-base-dev 2>/dev/null || true
apt-get autoremove --purge -y

# 5. Wipe Rscript-installed packages — these are source builds that won't be
#    binary-compatible with the upcoming r2u install of R.
echo "--- Removing source-built R packages under /usr/local/lib/R/..."
rm -rf /usr/local/lib/R/site-library
# /usr/local/lib/R only ever held site-library on Ubuntu; rmdir-if-empty.
rmdir /usr/local/lib/R 2>/dev/null || true

# 6. Report (don't remove) the build-deps the old script installed.
#    Other system packages may still need libssl-dev, libxml2-dev, etc.
echo
echo "--- Heavy build-deps from the old install (review and remove if unused) ---"
build_deps=(
    libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev
    libtiff5-dev libjpeg-dev libxml2-dev libcurl4-openssl-dev
    libfontconfig1-dev libssl-dev libcairo2-dev
)
still_installed=()
for p in "${build_deps[@]}"; do
    if pkg_installed "$p"; then
        still_installed+=("$p")
        echo "  $p"
    fi
done
echo
if (( ${#still_installed[@]} > 0 )); then
    echo "If nothing else on this host needs them:"
    echo "  sudo apt-get purge ${still_installed[*]}"
    echo "  sudo apt-get autoremove --purge"
fi
echo
echo "=== Cleanup complete. ==="
echo "Now re-run ubuntu/my_ubuntu_setup.sh (or just its R section) to install"
echo "R via r2u — binary CRAN packages, no compile."
