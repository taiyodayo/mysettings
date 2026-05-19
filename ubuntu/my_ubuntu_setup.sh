#!/usr/bin/env bash
# ubuntu サーバを共通でセットアップします
# Re-entrant: safe to run repeatedly. Each section guards against
# duplicate state (apt-get install is idempotent, file edits are guarded
# with grep, restart-docker only fires when the CA cert actually changed).
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" >&2
   exit 1
fi
if [[ -z "${SUDO_USER:-}" ]]; then
   echo "ERROR: SUDO_USER is not set." >&2
   echo "Run via 'sudo' from the target user account, not directly as root." >&2
   exit 1
fi

echo "--- mailab ubuntu server kitting script ---"

# Resolve the repo root once so all the common/ + packages/ helpers below
# can use a stable absolute path regardless of how the script was invoked.
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"

# Keep the host on current upstream — version-sensitive work runs in Docker,
# not pinned on the host. (See ATTACKPLAN.md §3 principle 6.) This runs first
# so the rest of the kit installs against current apt indexes / package
# versions, not whatever was current when the image was last booted.
echo "--- apt update + upgrade (chasing current upstream) ---"
apt-get update
apt-get upgrade -y

# apt packages — canonical list lives in packages/linux_base.yml so the
# Ansible playbook (automated/ubuntu_kitting.yml) reads the same set.
# Add / remove there, not here.
#
# `awk '/^- / { print $2 }'` extracts the package name from each YAML
# array entry. No yq dependency — yq itself is one of the things the kit
# installs, so we can't depend on it during bootstrap.
awk '/^- / { print $2 }' "$SCRIPT_DIR/packages/linux_base.yml" \
  | xargs -r apt-get install -y

# yq (mikefarah/yq, Go-based YAML processor — not the python-yq that apt ships
# as `yq`). snap is the upstream-recommended Linux distribution channel.
# Idempotent: snap install is a no-op if already present.
if ! command -v yq >/dev/null 2>&1; then
    snap install yq
fi

# Remove any apt-managed Rust dev toolchain BEFORE the per-user rustup
# install in the userland section below — otherwise the two toolchains
# fight over PATH (apt's rustc/cargo land in /usr/bin which can shadow
# ~/.cargo/bin depending on rc ordering). apt-get purge returns 0 even
# if the packages aren't installed, so this is safe on a fresh box.
#
# NB: Ubuntu 26.04+ ships uutils coreutils (0.8.0) + sudo-rs as default
# system binaries — statically built Rust binaries on PATH, NOT a dev
# toolchain. Those stay. GNU fallbacks are available under gnu* names
# (gnucp, gnutr, gnudate, gnusha256sum, ...) if a script trips on a
# uutils flag difference. rustup is orthogonal to all of this and is
# what you actually want for Rust development work.
apt-get purge -y rustc cargo 2>/dev/null || true

# mise — install via the shared common script. Ubuntu uses the official
# mise.jdx.dev apt repo (so apt-get upgrade keeps it current); Mac uses
# brew. Per ATTACKPLAN feedback: prefer autoupdating install paths.
bash "$SCRIPT_DIR/common/install_mise.sh"

# gh (GitHub CLI) — 公式 apt リポジトリ。Ubuntu 同梱の gh は古いので、
# 公式リポを優先させて常に最新を取得する。
# Mirrors upstream verbatim (minus sudo, since this script already runs as root):
# https://github.com/cli/cli/blob/trunk/docs/install_linux.md
type -p wget >/dev/null || apt-get install -y wget
mkdir -p -m 755 /etc/apt/keyrings
out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && cat "$out" > /etc/apt/keyrings/githubcli-archive-keyring.gpg
chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
mkdir -p -m 755 /etc/apt/sources.list.d
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  > /etc/apt/sources.list.d/github-cli.list
apt-get update && apt-get install -y gh

# Dart SDK — install via the shared common script. Ubuntu uses Google's
# official apt repo (autoupdates via apt-get upgrade); Mac uses brew.
# fvm sits on top of this in the userland block below.
bash "$SCRIPT_DIR/common/install_dart.sh"

# タイムゾーンを東京に設定
timedatectl set-timezone Asia/Tokyo

# カーネルパラメータを調整 - これしないとビッグデータ・webスクレープ系のワークロードが不安定になることがある
if ! grep -qF 'vm.swappiness=10' /etc/sysctl.conf 2>/dev/null; then
    echo "vm.swappiness=10" | tee -a /etc/sysctl.conf
fi
sysctl -p

# Docker — install docker-ce from Docker Inc's official apt repo. Ubuntu's
# docker.io lags several major versions by mid-LTS cycle; docker-ce is on
# a current release cadence and is what the lab actually wants.
# Mirrors upstream: https://docs.docker.com/engine/install/ubuntu/

# Pre-flight: detect docker.io currently installed AND running containers.
# Switching docker.io → docker-ce purges then reinstalls the engine, which
# briefly stops all containers. Storage in /var/lib/docker survives, but
# containers without --restart=always do NOT auto-restart. On production
# hosts this is a deliberate operation requiring explicit consent.
DO_DOCKER_MIGRATION=1
if dpkg -l docker.io 2>/dev/null | grep -q '^ii'; then
    running=""
    if command -v docker >/dev/null 2>&1; then
        running=$(docker ps --format '{{.Names}}' 2>/dev/null | tr '\n' ' ')
    fi
    if [ -n "$running" ]; then
        count=$(echo "$running" | wc -w)
        echo ""
        echo "*** docker-ce migration warning ***"
        echo ""
        echo "  docker.io is installed and has $count running container(s):"
        echo "    $running"
        echo ""
        echo "  Continuing will: apt-get purge docker.io (stops all containers) →"
        echo "                   install docker-ce → containers can be restarted."
        echo "  Containers without --restart=always will NOT auto-restart."
        echo ""
        if [ -t 0 ]; then
            echo "  Press ENTER to continue with docker-ce migration, or any other key to skip."
            read -r -n 1 -s docker_key
            echo ""
            if [ "$docker_key" = "" ]; then
                echo "  Continuing with docker-ce migration..."
            else
                echo "  Skipping Docker section. docker.io remains installed."
                echo "  Re-run this script when ready to migrate."
                DO_DOCKER_MIGRATION=0
            fi
        else
            # Non-interactive (CI / piped). Proceed but log loudly so the
            # operator sees the warning in the output.
            echo "  (non-interactive shell — proceeding with migration. Containers will stop briefly.)"
        fi
    else
        echo "Note: docker.io installed but no containers running. Proceeding with docker-ce migration."
    fi
fi

if [ $DO_DOCKER_MIGRATION -eq 1 ]; then
# Remove Ubuntu-bundled / legacy Docker packages so they can't conflict on
# file ownership of /usr/bin/docker etc. Includes anything an older run of
# this script may have installed. apt-get purge returns 0 even when the
# packages aren't installed, so this is safe on a fresh box.
apt-get purge -y docker.io docker-doc docker-compose docker-compose-v2 \
    podman-docker containerd runc 2>/dev/null || true

# Docker's official GPG key + apt repo (modern /etc/apt/keyrings/ path).
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
    > /etc/apt/sources.list.d/docker.list

apt-get update
# docker-ce             — Engine
# docker-ce-cli         — CLI
# containerd.io         — Docker Inc's containerd build (replaces Ubuntu's
#                         `containerd` package, which we purged above)
# docker-buildx-plugin  — `docker buildx`
# docker-compose-plugin — `docker compose` v2 plugin (NOT the legacy v1
#                         `docker-compose` binary; install that separately
#                         via pip or apt if a workload still requires it)
apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

# Both docker.io and docker-ce auto-enable docker.service via postinst, but
# we set it explicitly in case of unusual install orderings on re-runs.
systemctl enable --now docker
fi  # end DO_DOCKER_MIGRATION

# ユーザを docker グループに追加 — always run, group exists for both docker.io and docker-ce
usermod -aG docker "${SUDO_USER}"
# # デフォルトのインセキュアレジストリを追加
# if [ ! -f /etc/docker/daemon.json ]; then
#   echo '{"insecure-registries" : ["rx-7.local:5000", "7.mai:5000"]}' | sudo tee /etc/docker/daemon.json
# fi
# boomer.local / boomer.mai は ssl を使用するようになった。
# 必要なルート証明書をコピー — only restart docker if the cert actually
# changed, otherwise re-runs needlessly bounce running containers.
ca_src="/home/${SUDO_USER}/mysettings/certs/mailab_root_ca.crt"
ca_dest=/usr/local/share/ca-certificates/mailab_root_ca.crt
if ! cmp -s "$ca_src" "$ca_dest" 2>/dev/null; then
    cp "$ca_src" "$ca_dest"
    update-ca-certificates
    systemctl restart docker
fi

# netdata — apt netdata was removed from Ubuntu 24.04 (noble) universe.
# Use netdata's own kickstart.sh which sets up their apt repo and installs
# from there. Works on 22.04, 24.04, 26.04. Idempotent via binary check.
# war roomへのノード追加はライセンス移行により辞めたほうが良くなった (no --claim-* flags).
if [ ! -x /usr/sbin/netdata ]; then
    curl -fsSL https://get.netdata.cloud/kickstart.sh \
        | bash -s -- --non-interactive --stable-channel --disable-telemetry --dont-wait
fi

# R via r2u — binary CRAN packages from Ubuntu apt.
# r2u only ships repos for current Ubuntu LTS (22.04 jammy / 24.04 noble).
# Skip the whole R install on non-LTS — there's no r2u source for it and
# we don't want to silently fall back to the slow CRAN-source workflow.
# 詳細: https://eddelbuettel.github.io/r2u/
if grep -q 'LTS' /etc/os-release; then
    # r2u repo — provides r-cran-* as binary debs.
    wget -qO- https://eddelbuettel.github.io/r2u/assets/dirk_eddelbuettel_key.asc \
      | tee /etc/apt/trusted.gpg.d/cranapt_key.asc > /dev/null
    echo "deb [arch=amd64] https://r2u.stat.illinois.edu/ubuntu $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/cranapt.list
    # Marutter CRAN repo — required alongside r2u: r2u's r-cran-* depend on
    # current r-base-core (≥4.5.0) which only the Marutter repo provides.
    wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc \
      | tee /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc > /dev/null
    echo "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/" \
      > /etc/apt/sources.list.d/cran_r.list
    # Pin r2u (origin: CRAN-Apt Project) so its packages always win over
    # Ubuntu's defaults. Single Pin: line — apt-preferences ignores extras.
    cat > /etc/apt/preferences.d/99cranapt <<'PIN'
Package: *
Pin: release o=CRAN-Apt Project
Pin-Priority: 700
PIN
    apt-get update
    # ONE apt transaction: r-base + bspm + the lab's R-DS preload.
    # Packages land in /usr/lib/R/site-library — visible to every user
    # the moment they type `R`. Personal extras go to each user's
    # ~/R/x86_64-pc-linux-gnu-library/ via install.packages() as usual.
    apt-get install -y --no-install-recommends \
      r-base r-base-dev \
      python3-dbus python3-gi python3-apt r-cran-bspm \
      r-cran-tidyverse r-cran-pacman r-cran-data.table \
      r-cran-arrow r-cran-jsonlite r-cran-readxl \
      r-cran-rmarkdown r-cran-knitr r-cran-devtools \
      r-cran-renv r-cran-languageserver r-cran-httpgd
    # Deploy /usr/local/bin/r-install wrapper + r-installers group +
    # sudoers rule, so non-root users can install r-cran-* packages
    # system-wide via `sudo r-install ...` (the wrapper enforces a strict
    # r-cran-* whitelist; the sudoers rule grants NOPASSWD ONLY on the
    # wrapper, not apt-get directly).
    install -m 0755 -o root -g root \
        "$(dirname "$(readlink -f "$0")")/../cli_tools/r-install.sh" \
        /usr/local/bin/r-install
    groupadd -f r-installers
    cat > /etc/sudoers.d/r-installers <<'SUDOERS'
# Members of r-installers may run /usr/local/bin/r-install without
# password. The wrapper validates that every argument is r-cran-* and
# exec's `apt-get install`; removal is intentionally not granted.
%r-installers ALL=(root) NOPASSWD: /usr/local/bin/r-install
SUDOERS
    chmod 0440 /etc/sudoers.d/r-installers
    # Add the kitting user to r-installers (admin can add others later
    # with `sudo usermod -aG r-installers <user>`).
    usermod -aG r-installers "$SUDO_USER"

    # Configure /etc/R/Rprofile.site:
    # - Root R sessions get bspm (apt-binary install.packages → system lib)
    # - install_apt() helper: same fast path for non-root users via sudo
    #   r-install. install.packages() in user sessions stays untouched
    #   (source compile to ~/R/.../) so personal/experimental work
    #   doesn't accidentally pollute system lib.
    rprofile=/etc/R/Rprofile.site
    # Strip any flat-style bspm lines and earlier marker variants
    sed -i '/^suppressMessages(bspm::enable())/d; /^options(bspm.version.check=FALSE)/d' "$rprofile" 2>/dev/null || true
    sed -i '/# === BEGIN mysettings bspm ===/,/# === END mysettings bspm ===/d' "$rprofile" 2>/dev/null || true
    sed -i '/# === BEGIN mysettings R config ===/,/# === END mysettings R config ===/d' "$rprofile" 2>/dev/null || true
    cat >> "$rprofile" <<'PROF'
# === BEGIN mysettings R config ===
# Root R: bspm enabled → install.packages() goes via apt to system lib.
if (Sys.info()[["effective_user"]] == "root") {
    options(bspm.sudo = TRUE)
    options(bspm.version.check = FALSE)
    suppressMessages(bspm::enable())
}

# install_apt(): non-root binary install via the r-install wrapper.
# Available to everyone, but the underlying sudo only succeeds for users
# in the r-installers group. Goes to system lib, visible to everyone.
# Plain install.packages() is unchanged → user lib (source compile).
install_apt <- function(...) {
    pkgs <- unlist(list(...))
    if (length(pkgs) == 0L) stop("install_apt: no packages given")
    if (any(grepl("[^a-zA-Z0-9._-]", pkgs))) {
        stop("install_apt: package names must be alphanumeric / . _ -")
    }
    apt_names <- paste0("r-cran-", tolower(gsub("[._]", "-", pkgs)))
    cat("install_apt: sudo r-install ", paste(apt_names, collapse = " "), "\n", sep = "")
    rc <- system2("sudo", c("-n", "/usr/local/bin/r-install", apt_names))
    invisible(rc == 0L)
}
# === END mysettings R config ===
PROF
    # Sanity check that the lab can actually use this R out of the box.
    cli_tools_dir="$(dirname "$(readlink -f "$0")")/../cli_tools"
    if [ -x "$cli_tools_dir/check_r.sh" ]; then
        "$cli_tools_dir/check_r.sh" || \
            echo "*** WARNING: check_r.sh reported missing pieces. ***"
    fi
else
    pretty=$(. /etc/os-release; echo "$PRETTY_NAME")
    echo "*** Skipping R/r2u install: $pretty is not LTS. ***"
    echo "*** r2u supports Ubuntu LTS only — re-run R section after upgrade. ***"
fi

# misc/datatools でよく使うパッケージ
# No version pinning — host chases current upstream (ATTACKPLAN.md §3.6).
# Version-sensitive PDF work (e.g. gs 9.55 for the Japanese mojibake fix)
# runs in Docker, not on the host. Ubuntu 26.04+ ships ImageMagick 7 in apt.
apt-get install -y ghostscript qpdf mupdf imagemagick


### ここからユーザランド ###
# here-document としてコマンドを列記
sudo -u "$SUDO_USER" zsh << 'EOF'
echo "Running as $SUDO_USER"

# Repo path inside the user heredoc — relies on the project convention that
# the repo lives at ~/mysettings (enforced by setup_mailab_ubuntu-ansible.sh).
MYSETTINGS_DIR="$HOME/mysettings"

# Homebrew on Linux is DEPRECATED.
#
# Why: apt + curl-pipe-sh covers everything we need (gh, mise, bat, eza,
# rustup, uv, claude-native, bun). linuxbrew creates a parallel package
# universe at /home/linuxbrew/ that:
#   - Duplicates things apt has (gh, mise, uv) and shadows our canonical
#     installs via PATH ordering — caught by cli_tools/check_tools.sh
#   - Pulls in its own libgcc/glibc shims that occasionally conflict
#     with system tooling
#   - Adds ~500 MB on disk + slow upgrade cycle vs apt's fast binary debs
#
# Mac brew is unchanged — it's the canonical Mac package manager.
# Existing linuxbrew installs on this fleet are NOT auto-removed — kitting
# detects them and prints the uninstall command. Run cli_tools/check_tools.sh
# anytime to see the warning + recommended action.
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    echo ""
    echo "*** linuxbrew is deprecated ***"
    echo "  /home/linuxbrew/.linuxbrew/bin/brew detected. We no longer install"
    echo "  linuxbrew during kitting. To remove it (recommended):"
    echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\""
    echo "  Existing installs still work (~/.zshrc still sources brew shellenv"
    echo "  if found), but tools should migrate to apt / curl-pipe-sh."
    echo ""
fi

# mise activate hook in ~/.zshrc (mise binary installed by the root block
# above via common/install_mise.sh). chezmoi's dot_zshrc.tmpl already
# handles this for chezmoi-managed shells; the inline append below keeps
# pre-chezmoi machines working.
eval "$(mise activate zsh)"
if [ ! -f ~/.zshrc ] || ! grep -Fq 'mise activate zsh' ~/.zshrc; then
  cat >> ~/.zshrc <<-'EOM'
# mise
eval "$(mise activate zsh)"
EOM
fi

# node@lts via mise — shared with the Mac kit.
bash "$MYSETTINGS_DIR/common/install_node.sh"

# uv + ~/p313 venv + lab DS preload — shared with the Mac kit. The
# common script delegates uv install to dotfiles/run_onchange_install-uv.sh
# (astral.sh's curl installer on Linux), then creates the cpython-3.13
# venv at ~/p313 and preloads polars, pandas, numpy, etc. per
# packages/lab_python.yml. dot_zshrc.tmpl sources the venv's activate
# on every shell; the imperative ~/.zshrc append below keeps
# pre-chezmoi machines working.
bash "$MYSETTINGS_DIR/common/install_uv_and_p313.sh"
# Installer adds ~/.local/bin to ~/.zshrc but not this shell; activate.
export PATH="$HOME/.local/bin:$PATH"
if [ ! -f ~/.zshrc ] || ! grep -Fq 'p313/bin/activate' ~/.zshrc; then
    echo 'source ~/p313/bin/activate' >> ~/.zshrc
fi

# bun — shared with the Mac kit. cli_tools/llms_update.sh uses `bun add -g`
# for codex/gemini, so bun must be on PATH before that runs.
bash "$MYSETTINGS_DIR/common/install_bun.sh"
# Activate for this session (installer adds ~/.bun/bin to .zshrc, but not
# the current shell). dot_zshrc.tmpl picks it up via `[ -d "$HOME/.bun" ]`.
[ -d "$HOME/.bun" ] && export PATH="$HOME/.bun/bin:$PATH"

# rustup + the cargo CLI route — shared with the Mac kit. Single script
# installs rustup (or self-updates), cargo-binstall, and the 10-tool
# inventory (bat eza rg fd delta dust git-trim jless zellij qsv). System
# rustc/cargo (apt) were purged in the root section above so they can't
# shadow ~/.cargo/bin. The script writes ~/.cargo/env which the rustup
# installer appends to ~/.zshrc for future shells.
bash "$MYSETTINGS_DIR/dotfiles/run_onchange_install-rustup-and-cargo-tools.sh"
# Source cargo env so the rest of THIS heredoc (and check_tools.sh below)
# can resolve ~/.cargo/bin without waiting for a re-login.
# shellcheck source=/dev/null
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# fvm + Flutter — shared with the Mac kit. Skip if dart didn't install
# (root-block install_dart.sh would have failed; common script gates on
# command -v dart). dot_zshrc.tmpl picks up ~/.pub-cache/bin long-term.
if command -v dart >/dev/null 2>&1; then
    bash "$MYSETTINGS_DIR/common/install_fvm_flutter.sh"
fi

# git global defaults — shared with the Mac kit.
bash "$MYSETTINGS_DIR/common/git_defaults.sh"

# netdata
# wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && \
#  sh /tmp/netdata-kickstart.sh --stable-channel \
#    --claim-token xzdZDjRWCEdPau82Yt8xmcrvddTA01uUY4DLPpfQRDEbuGJJLMMhn8vG7uf3GmA4GLbr1Ce8dXyqyLHufGaZFHY72p1QAP3lm8ehJ_konTWhcgtlqB2bqhkGfhl5jK-eQl14Xb8 \
#    --claim-rooms 897e56af-6d74-438a-888f-12c38a879e7f \
#    --claim-url https://app.netdata.cloud

# Add custom CLI tools directory to PATH
if [ ! -f ~/.zshrc ] || ! grep -Fq 'mysettings/cli_tools' ~/.zshrc; then
  echo 'export PATH="$HOME/mysettings/cli_tools:$PATH"' >> ~/.zshrc
fi
export PATH="$HOME/mysettings/cli_tools:$PATH"

# Consolidated login check (gh, claude, codex, gemini). stdin is a here-doc
# here, so login_check.sh runs in non-interactive mode — it reports status
# and prints the commands to run, without blocking the kitting flow. Run
# `login_check.sh` from an interactive shell afterward to actually log in.
if [ -x "$HOME/mysettings/cli_tools/login_check.sh" ]; then
    "$HOME/mysettings/cli_tools/login_check.sh"
fi

# Consolidated tool consistency audit. Reports non-canonical installs +
# duplicates of managed CLI tools. Read-only by default. Re-run with --fix
# afterward to auto-purge user-owned duplicates (bat in ~/.cargo, claude in
# ~/.bun, etc.) — see cli_tools/check_tools.sh --help.
if [ -x "$HOME/mysettings/cli_tools/check_tools.sh" ]; then
    "$HOME/mysettings/cli_tools/check_tools.sh"
fi

# taiyo 実行ここまで
EOF

echo "Running as root"
# 最後の通知
echo "Kitting completed. please logout to activate changes"
#[EOF]
