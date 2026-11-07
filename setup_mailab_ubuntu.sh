#!/usr/bin/env bash
# Tool setup entry point. Native packages: machine native; GUI/R setup is opt-in.
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/cli_tools/machine" setup ubuntu-server
