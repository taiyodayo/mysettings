#!/usr/bin/env bash
set -euo pipefail
if [[ ${1:-} == --fix ]]; then
    echo 'Automatic deletion retired. Use machine cleanup for a preview.' >&2
    exit 1
fi
exec "$(dirname "${BASH_SOURCE[0]}")/machine" doctor
