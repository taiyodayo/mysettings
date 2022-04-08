#!/usr/bin/env bash

# setup brew for macs
if [ "$(uname)" = "Darwin" ] && [ ! -f /usr/local/bin/brew ] ; then
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# setup sdkman for java
echo "setup sdkman for java:"
curl -s "https://get.sdkman.io" | bash && source "${HOME}/.sdkman/bin/sdkman-init.sh" && sdk install java

# miniconda
echo "Setting up miniconda"
if [ "$(uname)" = "Linux" ] ; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    bash Miniconda3-latest-Linux-x86_64.sh
fi

if [ "$(uname)" = "Darwin" ] && [ "$(uname -p)" = "arm64" ] ; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-arm64.sh
    bash Miniconda3-latest-MacOSX-arm64.sh
fi

if [ "$(uname)" = "Darwin" ] && [ "$(uname -p)" = "i386" ] ; then
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-x86_64.sh
    bash Miniconda3-latest-MacOSX-x86_64.sh
fi
