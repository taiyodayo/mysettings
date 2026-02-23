#!/usr/bin/env bash
# ubuntu サーバを共通でセットアップします
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root"
  exit 1
fi

TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  TARGET_USER=""
fi

echo "--- mailab ubuntu server kitting script ---"
echo "Press ENTER to continue or any other key to exit."
# Read a single character
read -r -n 1 -s key
# Check the value of the key
if [ "$key" = "" ]; then
    echo "Continuing..."
else
    echo "Exiting..."
    exit 0
fi

# apt - 全体でよく使うパッケージ
apt-get update
apt-get install -y zsh avahi-daemon parallel wireguard-tools nkf iftop iotop rclone lm-sensors fonts-firacode build-essential

# タイムゾーンを東京に設定
timedatectl set-timezone Asia/Tokyo

# カーネルパラメータを調整 - これしないとビッグデータ・webスクレープ系のワークロードが不安定になることがある
echo "vm.swappiness=10" | tee -a /etc/sysctl.conf
sysctl -p

sudo apt-get install -y docker.io docker-compose-plugin

# ユーザを docker グループに追加
if [ -n "$TARGET_USER" ]; then
  usermod -aG docker "$TARGET_USER"
fi

# # 必要なルート証明書をコピー
if [ -n "$TARGET_USER" ]; then
  CERT_SRC="/home/${TARGET_USER}/mysettings/certs/mailab_root_ca.crt"
  if [ -f "$CERT_SRC" ]; then
    cp "$CERT_SRC" /usr/local/share/ca-certificates
  else
    echo "Certificate not found: $CERT_SRC"
  fi
fi
# 証明書を更新
update-ca-certificates
# docker をリスタート
systemctl restart docker

# netdata
apt-get install -y netdata

# R の部
# aptでいれるのが一番早い。war roomへのノード追加はライセンス移行により辞めたほうが良くなった。
# install two helper packages we need
apt install -y --no-install-recommends software-properties-common dirmngr
# add the signing key (by Michael Rutter) for these repos
# To verify key, run gpg --show-keys /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
# Fingerprint: E298A3A825C0D65DFD57CBB651716619E084DAB9
# cran の apt レポを追加
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
# add the R 4.0 repo from CRAN -- adjust 'focal' to 'groovy' or 'bionic' as needed
add-apt-repository -y "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
# インストール
apt-get update
apt-get install -y r-base
# tidyverseのビルドに必要なパッケージを追加
apt-get install -y libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
  libxml2-dev libcurl4-openssl-dev libfontconfig1-dev libssl-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev libxml2-dev libcairo2-dev
# 多用するパッケージはsudo で全ユーザ向けにインストールしておく
Rscript -e 'install.packages("pacman")'
Rscript -e 'pacman::p_load(tidyverse, lubridate, stringr, languageserver, httpgd)'

# misc/datatools でよく使うパッケージ
if [ "${WITH_LINUX_BREW:-1}" = "1" ] && [ -n "$TARGET_USER" ]; then
  # homebrew - ghostscript9, imagemagick7 via imei
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  TARGET_HOME="/home/${TARGET_USER}"
  (echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> "${TARGET_HOME}/.zprofile"
fi

# gs 10はPDF処理にバグがあって使用できない！！ (使うと日本語文字が散発的に化ける) gs9.55を指定してインストール
apt-get install -y ghostscript=9.55.0~dfsg1-0ubuntu5.4 qpdf mupdf
# gs9.55 を使用するため、ソースからIM7をビルド
t=$(mktemp) && \
  wget 'https://dist.1-2.dev/imei.sh' -qO "$t" && \
  bash "$t" && \
  rm "$t"


### ここからユーザランド ###
if [ -n "$TARGET_USER" ]; then
  # here-document としてコマンドを列記
  sudo -u "$TARGET_USER" TARGET_USER="$TARGET_USER" zsh << 'EOF'
  echo "Running as $TARGET_USER"

  if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
    # Linuxbrew for user tooling only; build tooling stays apt-managed.
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    brew install bun uv
  fi

  # git のデフォルト
  git config --global user.name "${TARGET_USER}@$(hostname) default"
  git config --global user.email "taiyodayo@gmail.com"

  # netdata
  # wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && \
  #  sh /tmp/netdata-kickstart.sh --stable-channel \
  #    --claim-token xzdZDjRWCEdPau82Yt8xmcrvddTA01uUY4DLPpfQRDEbuGJJLMMhn8vG7uf3GmA4GLbr1Ce8dXyqyLHufGaZFHY72p1QAP3lm8ehJ_konTWhcgtlqB2bqhkGfhl5jK-eQl14Xb8 \
  #    --claim-rooms 897e56af-6d74-438a-888f-12c38a879e7f \
  #    --claim-url https://app.netdata.cloud

  # taiyo 実行ここまで
EOF
fi

echo "Running as root"
# 最後の通知
echo "Kitting completed. please logout to activate changes"
