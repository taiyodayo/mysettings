#!/usr/bin/env bash
# Install the Dart SDK.
#
# Per ATTACKPLAN feedback: prefer autoupdating install paths.
#   Mac    → brew install dart-sdk            (brew upgrade keeps it current)
#   Ubuntu → Google's official apt repo + apt install dart
#            (apt-get upgrade keeps it current)
#
# Dart is needed for Flutter Version Manager (fvm) — see install_fvm_flutter.sh.
#
# Privilege expectations:
#   Mac    — run as the target user.
#   Ubuntu — run as root (apt-repo setup needs root).

set -euo pipefail

case "$(uname -s)" in
    Darwin)
        if [[ $EUID -eq 0 ]]; then
            echo "ERROR: install_dart.sh on macOS must run as the target user, not root." >&2
            exit 1
        fi
        brew install dart-sdk
        ;;
    Linux)
        if [[ $EUID -ne 0 ]]; then
            echo "ERROR: install_dart.sh on Linux must run as root (apt-repo setup)." >&2
            exit 1
        fi
        # apt-transport-https is a hard requirement for the Dart repo URL scheme.
        apt-get install -y apt-transport-https
        mkdir -p -m 755 /etc/apt/keyrings
        # curl (not wget) to match install_mise.sh and keep the standalone
        # surface of this script minimal. setup_zsh_and_keys.sh installs
        # curl before either kitting flow gets here.
        curl -fsSL https://dl-ssl.google.com/linux/linux_signing_key.pub \
            | gpg --batch --yes --dearmor -o /etc/apt/keyrings/dart.gpg
        chmod go+r /etc/apt/keyrings/dart.gpg
        arch=$(dpkg --print-architecture)
        echo "deb [signed-by=/etc/apt/keyrings/dart.gpg arch=${arch}] https://storage.googleapis.com/download.dartlang.org/linux/debian stable main" \
            > /etc/apt/sources.list.d/dart_stable.list
        apt-get update
        apt-get install -y dart
        ;;
    *)
        echo "ERROR: install_dart.sh: unsupported OS $(uname -s)" >&2
        exit 1
        ;;
esac
