#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
authorized_keys="${HOME}/.ssh/authorized_keys"

# Pick the host bridge for the VM's secondary NIC. Try br0 first (the
# usual name on these machines); if it's missing, list available bridges
# and prompt. Override the default with MULTIPASS_BRIDGE=<name>.
bridge="${MULTIPASS_BRIDGE:-br0}"
if ! ip link show "${bridge}" >/dev/null 2>&1; then
  echo "Host bridge '${bridge}' not found." >&2
  available="$(ip -br link show type bridge 2>/dev/null | awk '{print $1}')"
  if [[ -z "${available}" ]]; then
    echo "ERROR: no bridges on this host; create one before launching." >&2
    exit 1
  fi
  echo "Available bridges:" >&2
  printf '  %s\n' ${available} >&2
  read -rp "Which bridge to use? " bridge
  if [[ -z "${bridge}" ]] || ! ip link show "${bridge}" >/dev/null 2>&1; then
    echo "ERROR: bridge '${bridge}' not found." >&2
    exit 1
  fi
fi

# Pre-flight: the chosen bridge must let bridged DHCP through to the LAN.
# With net.bridge.bridge-nf-call-iptables=1 (Ubuntu default) every bridged
# frame is run through the iptables FORWARD chain. On hosts where Docker
# or UFW set FORWARD policy to DROP (typical), the VM's DHCP DISCOVER
# from its tap is silently dropped, ens4 never gets a lease, and the
# interface sits in `degraded (configuring)` forever.
if [[ -z "${MULTIPASS_SKIP_BR0_CHECK:-}" ]]; then
  nf_call=/proc/sys/net/bridge/bridge-nf-call-iptables
  if [[ -r "${nf_call}" && "$(cat "${nf_call}")" == "1" ]]; then
    cat >&2 <<EOF
ERROR: bridged DHCP on ${bridge} will be dropped by host iptables.

net.bridge.bridge-nf-call-iptables=1 sends bridged frames through the
iptables FORWARD chain. With Docker/UFW installed the chain's policy is
DROP, so the VM's DHCP traffic across ${bridge} never reaches the LAN
and ens4 stays in 'degraded (configuring)'.

Fix once on the host:

  ${script_dir}/setup_host_br0.sh

Re-run this script after applying. If you allowed FORWARD on ${bridge}
in some other way (e.g. explicit iptables ACCEPT rules), export
MULTIPASS_SKIP_BR0_CHECK=1 to bypass this check.
EOF
    exit 1
  fi
  unset nf_call
fi

if [[ ! -s "${authorized_keys}" ]]; then
  echo "No keys found at ${authorized_keys}" >&2
  exit 1
fi
keys_block="$(grep -v '^[[:space:]]*\(#\|$\)' "${authorized_keys}" | sed 's/^/      - /')"

name="${1:-}"
while [[ -z "${name}" ]]; do
  read -rp "Instance name: " name
done

if [[ -n "${TAIYO_PASSWORD_HASH:-}" ]]; then
  taiyo_password_hash="${TAIYO_PASSWORD_HASH}"
else
  if ! command -v openssl >/dev/null; then
    echo "openssl is required to hash the taiyo password" >&2
    exit 1
  fi

  while true; do
    read -rsp "New password for taiyo inside the VM: " taiyo_password
    echo
    read -rsp "Confirm new VM password for taiyo: " taiyo_password_confirm
    echo

    if [[ -z "${taiyo_password}" ]]; then
      echo "Password cannot be empty" >&2
    elif [[ "${taiyo_password}" == "${taiyo_password_confirm}" ]]; then
      break
    else
      echo "Passwords do not match" >&2
    fi
  done

  taiyo_password_hash="$(printf '%s' "${taiyo_password}" | openssl passwd -6 -stdin)"
  unset taiyo_password taiyo_password_confirm
fi

password_block="    lock_passwd: false
    passwd: '${taiyo_password_hash}'"

mac_suffix="$(printf '%s' "${name}" | sha256sum | cut -c1-6)"
bridge_mac="52:54:00:${mac_suffix:0:2}:${mac_suffix:2:2}:${mac_suffix:4:2}"

render_dir="${HOME}/snap/multipass/common/tmp"
mkdir -p "${render_dir}"
rendered="$(mktemp "${render_dir}/cloud-init.XXXXXX.yaml")"
chmod 0644 "${rendered}"
trap 'rm -f "${rendered}"' EXIT

awk -v block="${keys_block}" -v password_block="${password_block}" '
  /^__SSH_AUTHORIZED_KEYS__$/ { print block; next }
  /^__TAIYO_PASSWORD__$/ { if (password_block != "") print password_block; next }
  { print }
' "${script_dir}/bootstrap.yaml" > "${rendered}"

multipass launch 26.04 \
  --name "${name}" \
  --cpus $(( $(nproc) - 2 )) --memory 32G --disk 100G \
  --network "name=${bridge},mac=${bridge_mac}" \
  --cloud-init "${rendered}"

# Mount host's ~/.claude into the VM so claude opens already-authorised
# on first run. cloud-init has installed the binary and created
# /home/taiyo/.claude; here we:
#   1. mount host's ~/.claude → VM /home/taiyo/host-claude/
#   2. symlink VM ~/.claude/.credentials.json → /home/taiyo/host-claude/.credentials.json
# Step 2 runs ONLY if step 1 succeeds — otherwise we'd leave a dangling
# symlink that breaks `claude /login` (writes via the symlink target
# fail ENOENT).
#
# UID/GID mapping: multipass's default is 1000:1000 on both sides, but
# the VM's taiyo is the SECOND user added by cloud-init (multipass's
# `default` user `ubuntu` claims UID 1000), so taiyo lands at UID 1001
# inside the VM. We query the VM-side UID/GID dynamically with a short
# retry — cloud-init may still be creating users when `multipass launch`
# returns — and fall back to 1001 if discovery fails.
#
# Mount persists across `multipass stop/start` and reboots. Remove with
# `multipass unmount ${name}:/home/taiyo/host-claude` if desired.
#
# Skip the whole thing: export MULTIPASS_SKIP_CLAUDE_MOUNT=1 (e.g. VM
# should authenticate independently, or you're testing the unauth flow).
if [[ -z "${MULTIPASS_SKIP_CLAUDE_MOUNT:-}" ]]; then
  if [[ ! -d "${HOME}/.claude" ]]; then
    echo "Note: ${HOME}/.claude does not exist on host — skipping credential mount." >&2
    echo "  VM claude will run unauthenticated; use \`claude /login\` on first run." >&2
    echo "  After logging in on the host (\`claude\`), re-mount with:" >&2
    echo "    multipass mount ${HOME}/.claude ${name}:/home/taiyo/host-claude --uid-map \$(id -u):1001 --gid-map \$(id -g):1001" >&2
    echo "    multipass exec ${name} -- sudo -u taiyo -H ln -sfn /home/taiyo/host-claude/.credentials.json /home/taiyo/.claude/.credentials.json" >&2
  else
    # Resolve VM taiyo's UID/GID. cloud-init's `users:` runs early, but
    # `multipass launch` can return before the user actually exists on
    # very slow hosts. Retry briefly.
    #
    # The actual VM-side UID depends on the multipass image's default-user
    # handling: depending on whether the image already has a UID-1000
    # `ubuntu` user, our taiyo lands at either 1000 or 1001. Always query;
    # never guess. A wrong UID map produces a silently-unreadable mount.
    vm_taiyo_uid=""
    vm_taiyo_gid=""
    for _ in 1 2 3 4 5; do
      vm_taiyo_uid="$(multipass exec "${name}" -- id -u taiyo 2>/dev/null || true)"
      vm_taiyo_gid="$(multipass exec "${name}" -- id -g taiyo 2>/dev/null || true)"
      [[ -n "${vm_taiyo_uid}" && -n "${vm_taiyo_gid}" ]] && break
      sleep 2
    done

    if [[ -z "${vm_taiyo_uid}" || -z "${vm_taiyo_gid}" ]]; then
      # No safe default exists (1000 and 1001 are both real possibilities).
      # Skipping the mount instead of guessing — a wrong --uid-map produces
      # a mount where taiyo can't read the credentials, looking authed to
      # the script but unauthed to claude. Operator can re-mount once the
      # VM has finished provisioning the taiyo user.
      cat >&2 <<EOF
ERROR: could not detect VM taiyo UID/GID after 5 retries.
Skipping the credentials mount — a wrong UID map would make
~/.claude/.credentials.json silently unreadable inside the VM.

Once 'multipass exec ${name} -- id -u taiyo' returns a number, re-run:

  multipass mount ${HOME}/.claude ${name}:/home/taiyo/host-claude \\
      --uid-map \$(id -u):\$(multipass exec ${name} -- id -u taiyo) \\
      --gid-map \$(id -g):\$(multipass exec ${name} -- id -g taiyo)
  multipass exec ${name} -- sudo -u taiyo -H \\
      ln -sfn /home/taiyo/host-claude/.credentials.json \\
              /home/taiyo/.claude/.credentials.json
EOF
    elif multipass mount "${HOME}/.claude" "${name}:/home/taiyo/host-claude" \
          --uid-map "$(id -u):${vm_taiyo_uid}" \
          --gid-map "$(id -g):${vm_taiyo_gid}"; then
      # Mount succeeded — now safe to create the symlink. Done in the
      # VM (not at provisioning time) so the symlink only ever exists
      # when its target is reachable.
      if ! multipass exec "${name}" -- sudo -u taiyo -H \
            ln -sfn /home/taiyo/host-claude/.credentials.json \
                    /home/taiyo/.claude/.credentials.json; then
        echo "WARNING: failed to link credentials inside ${name}. Run manually:" >&2
        echo "  multipass exec ${name} -- sudo -u taiyo -H ln -sfn /home/taiyo/host-claude/.credentials.json /home/taiyo/.claude/.credentials.json" >&2
      fi
    else
      echo "WARNING: multipass mount of ~/.claude failed; claude inside ${name} will need 'claude /login' on first run." >&2
    fi
  fi
fi

multipass exec "${name}" -- bash -lc \
  'nohup sudo env DEBIAN_FRONTEND=noninteractive bash -lc "apt-get update && apt-get upgrade -y" >/tmp/apt-upgrade.log 2>&1 </dev/null &'

echo "Started background apt upgrade in ${name}; log: /tmp/apt-upgrade.log"
