#!/usr/bin/env bash
set -euo pipefail

vm_name="${VM_NAME:-nix-darwin-config-test}"
image="${TART_IMAGE:-ghcr.io/cirruslabs/macos-tahoe-base:latest}"
skip_network_updates="${VM_SKIP_NETWORK_UPDATES:-0}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
configuration="macbook"
if [[ "$skip_network_updates" = 1 ]]; then
  configuration="macbook-offline-test"
fi
system_path="$(nix build --no-link --print-out-paths "$repo_root#darwinConfigurations.$configuration.system")"
key_dir="$(mktemp -d /tmp/nix-darwin-vm.XXXXXX)"
ssh-keygen -q -t ed25519 -N '' -f "$key_dir/id_ed25519"
ssh_options=(
  -i "$key_dir/id_ed25519"
  -o IdentitiesOnly=yes
  -o ControlMaster=auto
  -o ControlPath="$key_dir/control-%r@%h:%p"
  -o ControlPersist=600
  -o StrictHostKeyChecking=no
  -o UserKnownHostsFile=/dev/null
  -o ConnectTimeout=15
)

run_tty_script() {
  local target="$1"
  local payload
  payload="$(base64 | tr -d '\n')"
  ssh -tt "${ssh_options[@]}" "$target" \
    "/bin/echo '$payload' | /usr/bin/base64 -D | /bin/bash"
}

if ! tart list --source local | awk 'NR > 1 { print $2 }' | grep -qx "$vm_name"; then
  tart clone "$image" "$vm_name"
fi
tart set "$vm_name" --disk-size "${VM_DISK_SIZE:-120}"

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
  echo admin | sudo -S sysadminctl -addUser joel.filho -fullName 'Nix Darwin Test User' -password vm-test-only -admin
fi
# Keep reruns deterministic even when an older disposable VM already contains
# the test account with a password from an earlier harness revision.
echo admin | sudo -S sysadminctl \
  -adminUser admin -adminPassword admin \
  -resetPasswordFor joel.filho -newPassword vm-test-only
echo admin | sudo -S mkdir -p /Users/joel.filho/Work
echo admin | sudo -S rm -rf /Users/joel.filho/Work/nix-darwin-config
echo admin | sudo -S cp -R /tmp/nix-darwin-config /Users/joel.filho/Work/nix-darwin-config
echo admin | sudo -S mkdir -p /Users/joel.filho/.ssh
echo admin | sudo -S cp /Users/admin/.ssh/authorized_keys /Users/joel.filho/.ssh/authorized_keys
echo admin | sudo -S chmod 700 /Users/joel.filho/.ssh
echo admin | sudo -S chmod 600 /Users/joel.filho/.ssh/authorized_keys
echo admin | sudo -S chown -R joel.filho:staff /Users/joel.filho
REMOTE

# The evaluated system output is local and therefore absent from the public
# binary cache. Copy its closure directly to the same-architecture guest so a
# cache outage or a slow negative lookup cannot make activation nondeterministic.
NIX_SSHOPTS="${ssh_options[*]}" \
  nix copy --no-check-sigs --to "ssh-ng://joel.filho@$ip" "$system_path"
# Intentional client-side expansion passes the exact prebuilt store path.
# shellcheck disable=SC2029
ssh "${ssh_options[@]}" admin@"$ip" \
  "/usr/bin/printf '%s\\n' '$system_path' > /tmp/nix-darwin-system-path"
# shellcheck disable=SC2029
ssh "${ssh_options[@]}" admin@"$ip" \
  "/usr/bin/printf '%s\\n' '$skip_network_updates' > /tmp/nix-darwin-skip-network"

# Run activation as the declared primary user. Some signed Homebrew casks use
# Apple's privileged package installer; keeping this user's sudo ticket fresh
# mirrors an interactive first installation without granting passwordless root.
# A successful immediate reboot drops SSH before it can report a clean exit.
# The marker is checked after boot so an earlier activation failure stays fatal.
run_tty_script joel.filho@"$ip" <<'REMOTE' || true
set -euo pipefail
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
printf '%s\n' vm-test-only | sudo -S -v
while sudo -n -v; do sleep 30; done &
sudo_keeper=$!
trap 'kill "$sudo_keeper" 2>/dev/null || true' EXIT
target_system="$(/bin/cat /tmp/nix-darwin-system-path)"
skip_network_updates="$(/bin/cat /tmp/nix-darwin-skip-network)"
/usr/bin/printf '%s\n' "$skip_network_updates" | sudo /usr/bin/tee /var/db/nix-darwin-skip-network >/dev/null
sudo /nix/var/nix/profiles/default/bin/nix-env \
  -p /nix/var/nix/profiles/system --set "$target_system"
if [[ "$skip_network_updates" = 1 ]]; then
  sudo /usr/bin/env \
    NIX_DARWIN_SKIP_NETWORK_UPDATES=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    "$target_system/activate"
else
  sudo "$target_system/activate"
fi
sudo /usr/bin/touch /var/db/nix-darwin-first-activation-complete
sudo shutdown -r now
REMOTE

for _ in $(seq 1 60); do
  ssh "${ssh_options[@]}" admin@"$ip" true >/dev/null 2>&1 || break
  sleep 2
done
for _ in $(seq 1 120); do
  ssh "${ssh_options[@]}" admin@"$ip" true >/dev/null 2>&1 && break
  sleep 5
done

run_tty_script joel.filho@"$ip" <<'REMOTE'
set -euo pipefail
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
test -f /var/db/nix-darwin-first-activation-complete
printf '%s\n' vm-test-only | sudo -S -v
while sudo -n -v; do sleep 30; done &
sudo_keeper=$!
trap 'kill "$sudo_keeper" 2>/dev/null || true' EXIT
if ! nix --extra-experimental-features nix-command store ping --store daemon >/dev/null 2>&1; then
  sudo launchctl kickstart -k system/org.nixos.nix-daemon
  for _ in $(seq 1 30); do
    nix --extra-experimental-features nix-command store ping --store daemon >/dev/null 2>&1 && break
    sleep 1
  done
  nix --extra-experimental-features nix-command store ping --store daemon >/dev/null
fi
skip_network_updates="$(/bin/cat /var/db/nix-darwin-skip-network)"
if [[ "$skip_network_updates" = 1 ]]; then
  sudo /usr/bin/env \
    NIX_DARWIN_SKIP_NETWORK_UPDATES=1 \
    HOMEBREW_NO_AUTO_UPDATE=1 \
    /run/current-system/sw/bin/darwin-rebuild activate
else
  sudo /run/current-system/sw/bin/darwin-rebuild activate
  /Users/joel.filho/.local/bin/ai-tools-update
fi
SMOKE_SKIP_NETWORK_BOOTSTRAP="$skip_network_updates" \
  /Users/joel.filho/Work/nix-darwin-config/tests/smoke-test.sh
REMOTE

echo "VM activation and smoke tests passed on $vm_name ($ip)"
