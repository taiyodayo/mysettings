#!/usr/bin/env bash
# ubuntu サーバを共通でセットアップします
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
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
curl -fsSL https://mise.jdx.dev/gpg-key.pub | gpg --dearmor -o /etc/apt/keyrings/mise-archive-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" | tee /etc/apt/sources.list.d/mise.list
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
# 必要なルート証明書をコピー
cp "/home/${SUDO_USER}/mysettings/certs/mailab_root_ca.crt" /usr/local/share/ca-certificates
# 証明書を更新
update-ca-certificates
# docker をリスタート
systemctl restart docker

# netdata
# aptでいれるのが一番早い。war roomへのノード追加はライセンス移行により辞めたほうが良くなった。
apt-get install -y netdata

# R via r2u — binary CRAN packages from Ubuntu apt.
# r2u is locked to current Ubuntu LTS (22.04 jammy / 24.04 noble). Replaces
# the old CRAN-source workflow: no compile-time, no manual dev-package list,
# all CRAN dependencies resolved as binary debs.
# 詳細: https://eddelbuettel.github.io/r2u/
wget -qO- https://eddelbuettel.github.io/r2u/assets/dirk_eddelbuettel_key.asc \
  | tee /etc/apt/trusted.gpg.d/cranapt_key.asc > /dev/null
echo "deb [arch=amd64] https://r2u.stat.illinois.edu/ubuntu $(lsb_release -cs) main" \
  > /etc/apt/sources.list.d/cranapt.list
# Pin so r2u always wins over the default Ubuntu r-cran-* packages
cat > /etc/apt/preferences.d/99cranapt <<'PIN'
Package: *
Pin: release o=CRAN-Apt Project
Pin: release l=CRAN-Apt Packages
Pin-Priority: 700
PIN
apt-get update
apt-get install -y --no-install-recommends r-base r-base-dev
# bspm = Bridge to System Package Manager. After enabling, install.packages()
# in R uses apt under the hood, so any tooling that calls install.packages()
# (Rscript, RStudio, languageserver) also gets binary debs.
apt-get install -y python3-dbus python3-gi python3-apt
apt-get install -y --no-install-recommends r-cran-bspm
echo "suppressMessages(bspm::enable())"  >> /etc/R/Rprofile.site
echo "options(bspm.version.check=FALSE)" >> /etc/R/Rprofile.site
# 多用するパッケージ — pure binary install, no compile
apt-get install -y --no-install-recommends \
  r-cran-tidyverse r-cran-lubridate r-cran-stringr \
  r-cran-languageserver r-cran-httpgd

# misc/datatools でよく使うパッケージ
# ghostscript9, imagemagick7 via imei
# gs 10はPDF処理にバグがあって使用できない！！ (使うと日本語文字が散発的に化ける) gs9.55を指定してインストール
apt-get install -y ghostscript=9.55.0~dfsg1-0ubuntu5.4 qpdf mupdf
# gs9.55 を使用するため、ソースからIM7をビルド
t=$(mktemp) && \
  wget 'https://dist.1-2.dev/imei.sh' -qO "$t" && \
  bash "$t" && \
  rm "$t"


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
