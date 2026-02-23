#!/usr/bin/env bash
set -euo pipefail

# Keep one top-level entry point and let the shared plan map dispatch scripts.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="$SCRIPT_DIR"

source "$SCRIPT_DIR/setup_common.sh"

setup_parse_args "$@"
setup_dispatch "$PLATFORM" "$MODE"
