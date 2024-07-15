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
