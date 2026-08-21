# nix-darwin-config

Private, dendritic macOS configuration for an Apple Silicon MacBook. The flake combines:

- nixpkgs unstable, nix-darwin, Home Manager, flake-parts, and import-tree
- Nix for stable CLI/system packages
- nix-homebrew + nix-darwin's Homebrew module for proprietary and fast-moving apps
- SecretSpec with the 1Password provider for runtime secrets
- per-project `devenv` environments instead of global language stacks

`macbook` is the only host today. Every file under `modules/` is a flake-parts module and contributes a feature-owned Darwin or Home Manager module.

## Bootstrap

The target account is `joel.filho` on `aarch64-darwin`.

```bash
xcode-select --install
curl -L https://nixos.org/nix/install | sh -s -- --daemon
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
git clone git@github.com:JoelFrancisco/nix-darwin-config.git ~/Work/nix-darwin-config
cd ~/Work/nix-darwin-config
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#macbook
```

Subsequent rebuilds:

```bash
darwin-rebuild switch --flake ~/Work/nix-darwin-config#macbook
```

The first activation installs Homebrew packages/casks and runs the non-blocking AI bootstrap. Inspect `~/.local/state/ai-tools/bootstrap.log`, then rerun `ai-tools-update` if a vendor was temporarily unavailable.

## Secrets

No secret value is evaluated by Nix or written to the Nix store. SecretSpec resolves values only when a command/service starts.

1. Open and unlock 1Password; enable its CLI integration.
2. In the `Private` vault, create a Secure Note named `nix-darwin-config`.
3. Add a field named `OPENROUTER_API_KEY`. Optional fields are declared for OpenAI, Anthropic, and Gemini.
4. Verify:

```bash
op whoami
secretspec check --file ~/.config/nix-darwin/secretspec.toml --profile personal
```

Change the vault in `config/secretspec.toml` and `SECRETSPEC_PROVIDER` in `modules/shell.nix` if your personal vault has another name. CLIProxyAPI's OAuth files remain mutable at `~/.config/cli-proxy-api/auth` and are intentionally unmanaged.

## Latest policy

The two update models are deliberate:

- Nix packages are pinned in `flake.lock`. The scheduled workflow opens an update PR so failures can be reviewed and generations remain rollback-safe.
- GUI apps and vendor AI tools update on activation. `ai-tools-update` also refreshes OpenCode 1 (`latest`), OpenCode 2 (`next`), Executor, Claude, Hermes, the allow-listed public skills, and the ARM64 T3 Code nightly prerelease.

No Betha repository, skill, project trust entry, VPN credential, agent history, auth database, or runtime memory is copied into this repository.

## Manual approvals

macOS requires first-launch approval for 1Password integration, Raycast Accessibility, Tailscale and Proton VPN network extensions, notifications, microphone/camera access, and some app login items. Nix can install these apps but cannot safely bypass TCC or system-extension consent.

Command-Space is released from Spotlight and assigned to Raycast. Ghostty is associated with shell scripts and Unix executables; macOS has no single public system-wide “default terminal” setting.

## Checks and VM test

```bash
nix develop -c shellcheck scripts/* tests/*.sh
nix fmt -- --check $(rg --files -g '*.nix')
nix flake check --print-build-logs
./tests/vm-test.sh
```

The VM test uses a disposable Tart macOS guest, switches the configuration twice, reboots, and runs `tests/smoke-test.sh`. macOS guests cannot exercise nested virtualization engines, so the test verifies that OrbStack, Tart, and UTM install and launch; their actual container/VM engines must be smoke-tested on physical hardware.

Rollback remains available through `darwin-rebuild --list-generations` and `darwin-rebuild switch --rollback`.
