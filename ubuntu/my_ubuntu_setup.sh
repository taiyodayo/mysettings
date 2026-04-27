#!/usr/bin/env bash
# ubuntu サーバを共通でセットアップします
# Re-entrant: safe to run repeatedly. Each section guards against
# duplicate state (apt-get install is idempotent, file edits are guarded
# with grep, restart-docker only fires when the CA cert actually changed,
# IMEI only runs when ImageMagick isn't already installed).
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
echo "Press ENTER to continue or any other key to exit."
# Read a single character
read -r -n 1 -s key
# Check the value of the key
if [ "$key" = "" ]; then
    echo "Continuing..."
    # Put the rest of your script here
else
    echo "Exiting..."
    exit 0
fi

# apt - 全体でよく使うパッケージ
apt-get install -y zsh avahi-daemon parallel wireguard-tools nkf iftop iotop rclone lm-sensors \
  build-essential

# mise (公式 apt リポジトリ - brew より apt が推奨)
apt-get install -y gpg
mkdir -p /etc/apt/keyrings
# --batch --yes so re-runs overwrite the existing keyring without prompting
curl -fsSL https://mise.jdx.dev/gpg-key.pub \
  | gpg --batch --yes --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" \
  > /etc/apt/sources.list.d/mise.list
apt-get update && apt-get install -y mise

# タイムゾーンを東京に設定
timedatectl set-timezone Asia/Tokyo

# カーネルパラメータを調整 - これしないとビッグデータ・webスクレープ系のワークロードが不安定になることがある
if ! grep -qF 'vm.swappiness=10' /etc/sysctl.conf 2>/dev/null; then
    echo "vm.swappiness=10" | tee -a /etc/sysctl.conf
fi
sysctl -p

# # docker-ce の部
# apt-get install -y apt-transport-https ca-certificates curl software-properties-common
# curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
# echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
# apt update
# apt-cache policy docker-ce
# apt-get install -y docker-ce
# # sudo systemctl status docker
# # docker-compose を使わないと mailab のコンテナと互換性が無いのに注意 `docker compose` への対応は先送り中
# apt-get install -y docker-compose

apt-get install -y docker.io docker-compose-plugin

# ユーザを docker グループに追加
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

# netdata
# aptでいれるのが一番早い。war roomへのノード追加はライセンス移行により辞めたほうが良くなった。
apt-get install -y netdata

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
    # Enable bspm globally so install.packages() / pacman::p_load() in any
    # later R session also resolve to apt binaries (RStudio install button,
    # Rscript pipelines, languageserver completions, etc.).
    # Guarded so re-runs don't duplicate the lines.
    grep -qF 'bspm::enable' /etc/R/Rprofile.site 2>/dev/null \
        || echo "suppressMessages(bspm::enable())"  >> /etc/R/Rprofile.site
    grep -qF 'bspm.version.check' /etc/R/Rprofile.site 2>/dev/null \
        || echo "options(bspm.version.check=FALSE)" >> /etc/R/Rprofile.site
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
# ghostscript9, imagemagick7 via imei
# gs 10はPDF処理にバグがあって使用できない！！ (使うと日本語文字が散発的に化ける) gs9.55を指定してインストール
apt-get install -y ghostscript=9.55.0~dfsg1-0ubuntu5.4 qpdf mupdf
# gs9.55 を使用するため、ソースからIM7をビルド (slow source compile;
# only run when ImageMagick 7 isn't already present so re-runs are fast)
if ! command -v magick >/dev/null 2>&1; then
    t=$(mktemp) && \
      wget 'https://dist.1-2.dev/imei.sh' -qO "$t" && \
      bash "$t" && \
      rm "$t"
fi


### ここからユーザランド ###
# here-document としてコマンドを列記
sudo -u "$SUDO_USER" zsh << 'EOF'
echo "Running as $SUDO_USER"

# Homebrew (ユーザランドでインストール - root では動かない。補助的に使用)
NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
# Add brew to shell profile if not already there
if ! grep -Fq 'linuxbrew' ~/.zprofile 2>/dev/null; then
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.zprofile
fi

# node / mise (apt で root セクションにてインストール済み)
eval "$(mise activate zsh)"
if [ ! -f ~/.zshrc ] || ! grep -Fq 'mise activate zsh' ~/.zshrc; then
  cat >> ~/.zshrc <<-'EOM'
# mise
eval "$(mise activate zsh)"
EOM
fi
mise use --global node@lts

# uv for Python (公式インストーラー - self-update 対応)
curl -LsSf https://astral.sh/uv/install.sh | sh
# installer adds ~/.local/bin to PATH via shell profile; activate for this session
export PATH="$HOME/.local/bin:$PATH"

# git のデフォルト
git config --global user.name "taiyo@$(hostname) default"
git config --global user.email "taiyodayo@gmail.com"

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

# taiyo 実行ここまで
EOF

echo "Running as root"
# 最後の通知
echo "Kitting completed. please logout to activate changes"
#[EOF]
