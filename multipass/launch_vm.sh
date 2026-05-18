#!/usr/bin/env bash
set -euo pipefail

name="${1:-}"
while [[ -z "${name}" ]]; do
  read -rp "Instance name: " name
done

multipass launch 26.04 \
  --name "${name}" \
  --cpus $(( $(nproc) - 2 )) --memory 32G --disk 100G \
  --cloud-init ./bootstrap.yaml
