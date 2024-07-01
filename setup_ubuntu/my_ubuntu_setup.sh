#!/usr/bin/env bash
# ubuntu サーバを共通でセットアップします
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
sudo apt install -y zsh avahi-daemon parallel wireguard-tools nkf iftop iotop rclone

# カーネルパラメータを調整 - これしないとビッグデータ・webスクレープ系のワークロードが不安定になることがある
echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# zsh のデフォルトを github から
# このあたりは taiyo 権限で実行する必要がある
sudo -u taiyo wget -O ~/.zshrc https://raw.githubusercontent.com/taiyodayo/mysettings/main/_zshrc 
sudo -u taiyo wget -O ~/.p10k.zsh https://raw.githubusercontent.com/taiyodayo/mysettings/main/_p10k.zsh
# バックグラウンドに投げて zinit の初期化を済ませておく
sudo -u taiyo zsh &
sudo -u taiyo chsh -s /usr/bin/zsh

# docker-ce の部
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
apt-cache policy docker-ce
sudo apt install -y docker-ce
# sudo systemctl status docker
# docker-compose を使わないと mailab のコンテナと互換性が無いのに注意 `docker compose` への対応は先送り中
sudo apt install -y docker-compose
# ユーザを docker グループに追加
sudo usermod -aG docker "${USER}"
# # デフォルトのインセキュアレジストリを追加
# if [ ! -f /etc/docker/daemon.json ]; then
#   echo '{"insecure-registries" : ["rx-7.local:5000", "7.mai:5000"]}' | sudo tee /etc/docker/daemon.json
# fi
# boomer.local / boomer.mai は ssl を使用するようになった。
# 必要なルート証明書をコピー
sudo cp ~/mysettings/setup_an_ubuntu_box/certs/mailab_root_ca.crt /usr/local/share/ca-certificates
# 証明書を更新
sudo update-ca-certificates
# docker をリスタート
sudo systemctl restart docker

# R の部
# ubuntu に tidyverse で必要なパッケージ
# キーを追加
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
# update indices
sudo apt update -qq
# install two helper packages we need
sudo apt install --no-install-recommends software-properties-common dirmngr
# add the signing key (by Michael Rutter) for these repos
# To verify key, run gpg --show-keys /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc 
# Fingerprint: E298A3A825C0D65DFD57CBB651716619E084DAB9
# cran の apt レポを追加
wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc
# add the R 4.0 repo from CRAN -- adjust 'focal' to 'groovy' or 'bionic' as needed
sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"
# インストール
sudo apt update
sudo apt install -y r-base
# tidyverseのビルドに必要なパッケージを追加
sudo apt install -y libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
  libxml2-dev libcurl4-openssl-dev libfontconfig1-dev libssl-dev libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev libxml2-dev libcairo2-dev
# 多用するパッケージはsudo で全ユーザ向けにインストールしておく
sudo Rscript -e 'install.packages("pacman")'
sudo Rscript -e 'pacman::p_load(tidyverse, lubridate, stringr, languageserver, httpgd)'

# misc/datatools でよく使うパッケージ
# homebrew - ghostscript9, imagemagick7 via imei
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
(echo; echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"') >> /home/taiyo/.zprofile
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
brew intall gcc
# gs 10はPDF処理にバグがあって使用できない！！ (使うと日本語文字が散発的に化ける) gs9.55を指定してインストール
sudo apt install ghostscript=9.55.0~dfsg1-0ubuntu5.4 qpdf mupdf
# gs9.55 を使用するため、ソースからIM7をビルド
t=$(mktemp) && \
  wget 'https://dist.1-2.dev/imei.sh' -qO "$t" && \
  sudo bash "$t" && \
  rm "$t"

# nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source "${HOME}/.zshrc"
nvm install 22
nvm use 22

# netdata
wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && \
  sh /tmp/netdata-kickstart.sh --stable-channel \
    --claim-token xzdZDjRWCEdPau82Yt8xmcrvddTA01uUY4DLPpfQRDEbuGJJLMMhn8vG7uf3GmA4GLbr1Ce8dXyqyLHufGaZFHY72p1QAP3lm8ehJ_konTWhcgtlqB2bqhkGfhl5jK-eQl14Xb8 \
    --claim-rooms 897e56af-6d74-438a-888f-12c38a879e7f \
    --claim-url https://app.netdata.cloud

# git のデフォルト
git config --global user.name "taiyo@$(hostname) default"
git config --global user.email "taiyodayo@gmail.com"

# 最後の通知
echo "Kitting completed. please logout to activate changes"
#[EOF]
