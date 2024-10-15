#!/usr/bin/env bash

# Basics
sudo apt install fonts-firacode

# Android-Studio
## Install Java JDK (if not already installed)
sudo apt install openjdk-11-jdk
## Add the Android Studio repository
sudo add-apt-repository ppa:maarten-fonville/android-studio
## Update package list
sudo apt update
## Install Android Studio
sudo apt install android-studio

# fvm / flutter
brew tap leoafarias/fvm
brew install fvm
##
fvm install stable
fvm global stable

# Google Chrome
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmour -o /usr/share/keyrings/google-chrome-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
sudo apt update
sudo apt install google-chrome-stable
