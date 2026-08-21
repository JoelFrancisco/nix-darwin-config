#!/usr/bin/env bash
set -euo pipefail

vm_name="${VM_NAME:-nix-darwin-config-test}"
image="${TART_IMAGE:-ghcr.io/cirruslabs/macos-tahoe-base:latest}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
ssh_options=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5)

if ! tart list --source local | awk 'NR > 1 { print $2 }' | grep -qx "$vm_name"; then
  tart clone "$image" "$vm_name"
fi

tart run "$vm_name" --no-graphics >"$repo_root/.vm-console.log" 2>&1 &
tart_pid=$!
trap 'kill "$tart_pid" 2>/dev/null || true' EXIT

ip=""
for _ in $(seq 1 120); do
  ip="$(tart ip "$vm_name" 2>/dev/null || true)"
  [[ -n "$ip" ]] && ssh "${ssh_options[@]}" admin@"$ip" true >/dev/null 2>&1 && break
  sleep 5
done
[[ -n "$ip" ]] || { echo "VM did not become reachable" >&2; exit 1; }

tar --exclude=.git --exclude=result --exclude='.vm-console.log' -C "$repo_root" -cf - . | \
  ssh "${ssh_options[@]}" admin@"$ip" 'rm -rf /tmp/nix-darwin-config && mkdir /tmp/nix-darwin-config && tar -C /tmp/nix-darwin-config -xf -'

ssh "${ssh_options[@]}" admin@"$ip" 'bash -s' <<'REMOTE'
set -euo pipefail
if [[ ! -x /nix/var/nix/profiles/default/bin/nix ]]; then
  curl -L https://nixos.org/nix/install -o /tmp/install-nix
  sh /tmp/install-nix --daemon --yes
fi
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

if ! id joel.filho >/dev/null 2>&1; then
  echo admin | sudo -S sysadminctl -addUser joel.filho -fullName 'Joel Francisco' -password vm-test-only -admin
fi
echo admin | sudo -S mkdir -p /Users/joel.filho/Work
echo admin | sudo -S cp -R /tmp/nix-darwin-config /Users/joel.filho/Work/nix-darwin-config
echo admin | sudo -S chown -R joel.filho:staff /Users/joel.filho

echo admin | sudo -S nix --extra-experimental-features 'nix-command flakes' run nix-darwin/master#darwin-rebuild -- switch --flake /Users/joel.filho/Work/nix-darwin-config#macbook
echo admin | sudo -S shutdown -r now
REMOTE

for _ in $(seq 1 60); do
  ssh "${ssh_options[@]}" admin@"$ip" true >/dev/null 2>&1 || break
  sleep 2
done
for _ in $(seq 1 120); do
  ssh "${ssh_options[@]}" admin@"$ip" true >/dev/null 2>&1 && break
  sleep 5
done

ssh "${ssh_options[@]}" admin@"$ip" 'bash -s' <<'REMOTE'
set -euo pipefail
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
echo admin | sudo -S /run/current-system/sw/bin/darwin-rebuild switch --flake /Users/joel.filho/Work/nix-darwin-config#macbook
echo admin | sudo -S -u joel.filho /Users/joel.filho/.local/bin/ai-tools-update
echo admin | sudo -S -u joel.filho /Users/joel.filho/Work/nix-darwin-config/tests/smoke-test.sh
REMOTE

echo "VM activation and smoke tests passed on $vm_name ($ip)"
