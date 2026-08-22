#!/usr/bin/env bash
set -euo pipefail

vm_name="${VM_NAME:-nix-darwin-config-test}"
image="${TART_IMAGE:-ghcr.io/cirruslabs/macos-tahoe-base:latest}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
key_dir="$(mktemp -d)"
ssh-keygen -q -t ed25519 -N '' -f "$key_dir/id_ed25519"
ssh_options=(
  -i "$key_dir/id_ed25519"
  -o IdentitiesOnly=yes
  -o ControlMaster=auto
  -o ControlPath="$key_dir/control"
  -o ControlPersist=600
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=15
)

if ! tart list --source local | awk 'NR > 1 { print $2 }' | grep -qx "$vm_name"; then
  tart clone "$image" "$vm_name"
fi

tart run "$vm_name" --no-graphics >"$repo_root/.vm-console.log" 2>&1 &
tart_pid=$!
cleanup() {
  kill "$tart_pid" 2>/dev/null || true
  rm -rf "$key_dir"
}
trap cleanup EXIT

ip=""
for _ in $(seq 1 120); do
  ip="$(tart ip "$vm_name" 2>/dev/null || true)"
  [[ -n "$ip" ]] && nc -z "$ip" 22 >/dev/null 2>&1 && break
  sleep 5
done
[[ -n "$ip" ]] || { echo "VM did not become reachable" >&2; exit 1; }

# Cirrus base images use admin/admin. Install a throwaway key once, then keep
# every provisioning command non-interactive. The private key is deleted by
# the EXIT trap and never enters the guest or repository.
key_b64="$(base64 <"$key_dir/id_ed25519.pub" | tr -d '\n')"
key_installed=false
for _ in $(seq 1 20); do
  if VM_IP="$ip" VM_KEY_B64="$key_b64" expect <<'EXPECT'
set timeout 30
set remote "umask 077; mkdir -p ~/.ssh; echo '$env(VM_KEY_B64)' | /usr/bin/base64 -D >> ~/.ssh/authorized_keys"
spawn ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null admin@$env(VM_IP) $remote
expect {
  "*assword:" { send "admin\r"; exp_continue }
  eof
}
catch wait result
exit [lindex $result 3]
EXPECT
  then
    key_installed=true
    break
  fi
  sleep 3
done
$key_installed || { echo "Could not install the ephemeral VM SSH key" >&2; exit 1; }

key_ready=false
for _ in $(seq 1 20); do
  if ssh "${ssh_options[@]}" admin@"$ip" true; then
    key_ready=true
    break
  fi
  sleep 3
done
$key_ready || { echo "VM did not accept the ephemeral SSH key" >&2; exit 1; }

tar --exclude=.git --exclude=result --exclude='.vm-console.log' -C "$repo_root" -cf - . | \
  ssh "${ssh_options[@]}" admin@"$ip" 'rm -rf /tmp/nix-darwin-config && mkdir /tmp/nix-darwin-config && tar -C /tmp/nix-darwin-config -xf -'

ssh "${ssh_options[@]}" admin@"$ip" 'bash -s' <<'REMOTE'
set -euo pipefail
if [[ ! -x /nix/var/nix/profiles/default/bin/nix ]]; then
  curl -L https://nixos.org/nix/install -o /tmp/install-nix
  sh /tmp/install-nix --daemon --yes
fi
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

if ! nix --extra-experimental-features nix-command store ping --store daemon >/dev/null 2>&1; then
  if ! echo admin | sudo -S launchctl print system/org.nixos.nix-daemon >/dev/null 2>&1; then
    echo admin | sudo -S launchctl bootstrap system /Library/LaunchDaemons/org.nixos.nix-daemon.plist
  fi
  echo admin | sudo -S launchctl kickstart -k system/org.nixos.nix-daemon
  for _ in $(seq 1 30); do
    nix --extra-experimental-features nix-command store ping --store daemon >/dev/null 2>&1 && break
    sleep 1
  done
  nix --extra-experimental-features nix-command store ping --store daemon >/dev/null
fi

# The official Nix installer owns these files first. nix-darwin deliberately
# requires an explicit backup before it takes them over on the initial switch.
for shell_file in /etc/bashrc /etc/zshrc; do
  if [[ -e "$shell_file" && ! -e "$shell_file.before-nix-darwin" ]]; then
    echo admin | sudo -S mv "$shell_file" "$shell_file.before-nix-darwin"
  fi
done

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
if ! nix --extra-experimental-features nix-command store ping --store daemon >/dev/null 2>&1; then
  echo admin | sudo -S launchctl kickstart -k system/org.nixos.nix-daemon
  for _ in $(seq 1 30); do
    nix --extra-experimental-features nix-command store ping --store daemon >/dev/null 2>&1 && break
    sleep 1
  done
  nix --extra-experimental-features nix-command store ping --store daemon >/dev/null
fi
echo admin | sudo -S /run/current-system/sw/bin/darwin-rebuild switch --flake /Users/joel.filho/Work/nix-darwin-config#macbook
echo admin | sudo -S -u joel.filho /Users/joel.filho/.local/bin/ai-tools-update
echo admin | sudo -S -u joel.filho /Users/joel.filho/Work/nix-darwin-config/tests/smoke-test.sh
REMOTE

echo "VM activation and smoke tests passed on $vm_name ($ip)"
