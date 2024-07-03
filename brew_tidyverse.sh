#!/usr/bin/env bash

# brew packages required for R/tidyverse on Mac
brew install libgit2 libsodium libtiff cmake libxml2 openssl curl harfbuzz fribidi
brew install R

# デフォルトのレポを設定
echo 'options(repos = c(CRAN = "https://ftp.yz.yamagata-u.ac.jp/pub/cran/"))' > ~/.Rprofile

# 多用するパッケージはsudo で全ユーザ向けにインストールしておく
Rscript -e 'install.packages("pacman")'
Rscript -e 'pacman::p_load(tidyverse, lubridate, stringr, languageserver, httpgd)'
