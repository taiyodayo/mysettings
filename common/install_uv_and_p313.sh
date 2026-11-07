#!/usr/bin/env bash
# Explicit opt-in lab environment. Existing ~/p313 is intentionally retained.
set -euo pipefail
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/cli_tools/machine" lab
