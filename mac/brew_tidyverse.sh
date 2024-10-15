#!/usr/bin/env bash

# brew packages required for R/tidyverse on Mac
brew install libgit2 libsodium libtiff cmake libxml2 openssl curl harfbuzz fribidi
# こうすると CRAN ディストリビューション外の R が入る。全てのパッケージのコンパイルが必要になってしまう
#brew install R
# CRAN ディストリビューションはこう。これだけでパッケージのビルドが不要になる！！！
brew install --cask r

# デフォルトのレポを設定
echo 'options(repos = c(CRAN = "https://ftp.yz.yamagata-u.ac.jp/pub/cran/"))' > ~/.Rprofile

# 多用するパッケージはsudo で全ユーザ向けにインストールしておく
Rscript -e 'install.packages("pacman")'
Rscript -e 'pacman::p_load(tidyverse, lubridate, stringr, languageserver, httpgd)'
