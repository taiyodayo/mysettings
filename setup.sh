#!/usr/bin/env bash
set -euo pipefail

# Common startup dispatcher for macOS and Ubuntu setup flows.
# Keep existing per-platform scripts as-is; this file only decides what to run.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'USAGE'
Usage: setup.sh [--platform auto|mac|ubuntu] [--mode auto|desktop|server|all]

platform:
  auto    Detect OS automatically (default)
  mac     Run macOS setup
  ubuntu  Run Ubuntu setup

mode:
  auto    macOS: full stack
          Ubuntu: root->server setup, non-root->GUI setup
  desktop  Run user-facing desktop setup path
  server   Ubuntu-only: run server setup (requires root)
  all      macOS: same as default
          Ubuntu: GUI setup then server setup (requires root)
USAGE
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

require_root() {
  ((EUID == 0)) || fail "This mode requires root privileges"
}

is_ubuntu() {
  [ -f /etc/os-release ] && grep -qi '^ID=ubuntu\|^ID_LIKE=.*ubuntu' /etc/os-release
}

run_macos() {
  "${SCRIPT_DIR}/setup_mac_all.sh"
}

run_ubuntu() {
  local mode=$1

  case "$mode" in
    auto)
      if ((EUID == 0)); then
        "${SCRIPT_DIR}/ubuntu/my_ubuntu_setup.sh"
      else
        "${SCRIPT_DIR}/ubuntu/setup_gui_tools.sh"
      fi
      ;;
    desktop)
      "${SCRIPT_DIR}/ubuntu/setup_gui_tools.sh"
      ;;
    server)
      require_root
      "${SCRIPT_DIR}/ubuntu/my_ubuntu_setup.sh"
      ;;
    all)
      require_root
      "${SCRIPT_DIR}/ubuntu/setup_gui_tools.sh"
      "${SCRIPT_DIR}/ubuntu/my_ubuntu_setup.sh"
      ;;
    *)
      fail "Unsupported mode '$mode' for ubuntu"
      ;;
  esac
}

PLATFORM="auto"
MODE="auto"

while (( "$#" > 0 )); do
  case "$1" in
    -p|--platform)
      PLATFORM="$2"; shift 2 ;;
    -m|--mode)
      MODE="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      fail "Unknown option: $1"
      ;;
  esac

done

case "$PLATFORM" in
  auto)
    case "$(uname -s)" in
      Darwin)
        run_macos
        ;;
      Linux)
        if is_ubuntu; then
          run_ubuntu "$MODE"
        else
          fail "Linux distro not recognized as Ubuntu. Set --platform ubuntu explicitly if this is Ubuntu-like."
        fi
        ;;
      *)
        fail "Unsupported platform: $(uname -s)"
        ;;
    esac
    ;;
  mac|macos)
    run_macos
    ;;
  ubuntu)
    if ! is_ubuntu; then
      fail "This system does not look like Ubuntu."
    fi
    run_ubuntu "$MODE"
    ;;
  *)
    fail "Unsupported platform: $PLATFORM"
    ;;
esac
