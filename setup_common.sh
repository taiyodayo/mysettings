#!/usr/bin/env bash
set -euo pipefail

# Shared execution dir when sourced directly, and safe for callers setting it explicitly.
: "${SETUP_DIR:=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# Shared usage text for a small, explicit CLI.
setup_usage() {
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
          Ubuntu: CLI/server setup first, then optional GUI tools (requires root)
          Ubuntu: set WITH_LINUX_BREW=0 to skip Linuxbrew in server flow
USAGE
}

# Plan declarations live in variables (string lists), not imperative branching.
PLAN_DARWIN_all="${SETUP_DIR}/setup_mac_all.sh"
PLAN_DARWIN_auto="${PLAN_DARWIN_all}"
PLAN_DARWIN_desktop="${PLAN_DARWIN_all}"
PLAN_DARWIN_server="${PLAN_DARWIN_all}"

PLAN_UBUNTU_ROOT_auto="${SETUP_DIR}/ubuntu/my_ubuntu_setup.sh"
PLAN_UBUNTU_ROOT_desktop="${SETUP_DIR}/ubuntu/setup_gui_tools.sh"
PLAN_UBUNTU_ROOT_server="${SETUP_DIR}/ubuntu/my_ubuntu_setup.sh"
PLAN_UBUNTU_ROOT_all="${SETUP_DIR}/ubuntu/my_ubuntu_setup.sh ${SETUP_DIR}/ubuntu/setup_gui_tools.sh"

PLAN_UBUNTU_USER_auto="${SETUP_DIR}/ubuntu/setup_gui_tools.sh"
PLAN_UBUNTU_USER_desktop="${PLAN_UBUNTU_USER_auto}"
PLAN_UBUNTU_USER_server=""
PLAN_UBUNTU_USER_all=""

PLAN_REQUIRE_ROOT_server=1
PLAN_REQUIRE_ROOT_all=1

setup_fail() {
  echo "ERROR: $*" >&2
  exit 1
}

setup_is_ubuntu() {
  [ -f /etc/os-release ] && grep -qi '^ID=ubuntu\|^ID_LIKE=.*ubuntu' /etc/os-release
}

setup_is_root() {
  [ "$(id -u)" -eq 0 ]
}

setup_require_root() {
  setup_is_root || setup_fail "This mode requires root privileges"
}

setup_plan_for() {
  local platform=$1
  local profile=$2
  local mode=$3
  local var="PLAN_${platform}_${profile}_${mode}"
  printf '%s' "${!var-}"
}

setup_run_plan() {
  local scripts="$1"
  local script

  [ -n "$scripts" ] || setup_fail "No scripts configured for selected platform/mode."

  for script in $scripts; do
    [ -f "$script" ] || setup_fail "Script not found: $script"
    if [ -x "$script" ]; then
      "$script"
    else
      bash "$script"
    fi
  done
}

setup_run_ubuntu() {
  local mode=$1
  local profile=USER
  local profile_label=non-root
  local require_root_var="PLAN_REQUIRE_ROOT_${mode}"

  setup_is_root && profile=ROOT
  if [ "$profile" = ROOT ]; then
    profile_label=root
  fi
  [ "${!require_root_var:-0}" = "1" ] && setup_require_root

  local scripts
  scripts="$(setup_plan_for "UBUNTU" "$profile" "$mode")"
  [ -n "$scripts" ] || setup_fail "Unsupported Ubuntu mode '$mode' for $profile_label mode."
  setup_run_plan "$scripts"
}

setup_run_macos() {
  local mode=$1
  local var="PLAN_DARWIN_${mode}"
  local scripts="${!var-}"
  [ -n "$scripts" ] || setup_fail "Unsupported macOS mode '$mode'."
  setup_run_plan "$scripts"
}

setup_parse_args() {
  PLATFORM="auto"
  MODE="auto"

  while (( "$#" > 0 )); do
    case "$1" in
      -p|--platform)
        [ "$#" -ge 2 ] || setup_fail "Option $1 requires a value."
        PLATFORM=$2
        shift 2
        ;;
      -m|--mode)
        [ "$#" -ge 2 ] || setup_fail "Option $1 requires a value."
        MODE=$2
        shift 2
        ;;
      -h|--help)
        setup_usage
        exit 0
        ;;
      *)
        setup_fail "Unknown option: $1"
        ;;
    esac
  done

  case "$PLATFORM" in
    auto|mac|macos|ubuntu) ;;
    *) setup_fail "Unsupported platform: $PLATFORM" ;;
  esac

  case "$MODE" in
    auto|desktop|server|all) ;;
    *) setup_fail "Unsupported mode: $MODE" ;;
  esac
}

setup_dispatch() {
  local platform=$1
  local mode=$2

  case "$platform" in
    auto)
      case "$(uname -s)" in
        Darwin)
          setup_run_macos "$mode"
          ;;
        Linux)
          setup_is_ubuntu || setup_fail "Linux distro not recognized as Ubuntu. Use --platform ubuntu explicitly."
          setup_run_ubuntu "$mode"
          ;;
        *)
          setup_fail "Unsupported platform: $(uname -s)"
          ;;
      esac
      ;;
    mac|macos)
      setup_run_macos "$mode"
      ;;
    ubuntu)
      setup_is_ubuntu || setup_fail "This system does not look like Ubuntu."
      setup_run_ubuntu "$mode"
      ;;
    *)
      setup_fail "Unsupported platform: $platform"
      ;;
  esac
}
