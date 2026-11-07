#!/usr/bin/env bash
# Compatibility entry point: machine profile must be selected explicitly first.
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/cli_tools/machine" apply
