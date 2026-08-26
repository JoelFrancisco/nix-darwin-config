# nix-darwin-config

Public, dendritic macOS configuration for an Apple Silicon MacBook. It is a
working personal configuration and a reference for building a similar setup.
The flake combines:

- nixpkgs unstable, nix-darwin, Home Manager, flake-parts, and import-tree
- Nix for stable CLI/system packages
- nix-homebrew + nix-darwin's Homebrew module for proprietary and fast-moving apps
- SecretSpec with the 1Password provider for runtime secrets
- Neovim managed by Home Manager with a LazyVim starter configuration
- per-project `devenv` environments instead of global language stacks

`macbook` is the only host today. Every file under `modules/` is a flake-parts module and contributes a feature-owned Darwin or Home Manager module.

## What it installs

The configuration includes Ghostty, LazyVim, tmux, Herdr, common Unix tools,
OrbStack, Tart, UTM, browsers, editors, communication apps, 1Password,
SecretSpec, and a local AI toolchain. Claude Code, Codex CLI, OpenCode stable,
Executor, and SecretSpec are Nix packages pinned by the flake. OpenCode 2,
Hermes, CLIProxyAPI, and T3 Code Nightly remain explicit mutable exceptions.
See `modules/apps.nix`, `modules/ai.nix`, and `scripts/ai-tools-update` for the
complete lists.

## Prerequisites

- An Apple Silicon Mac running a supported macOS release
- Administrator access
- Xcode Command Line Tools
- A 1Password account and the desktop app's CLI integration for runtime secrets
- A fork of this repository if you want to maintain your own configuration

## Customize before deployment

This checkout targets the `joel.filho` account. In a fork, edit the three
identity values at the top of `modules/host.nix`:

```nix
user = "your-macos-short-name";
gitName = "Your Name";
gitEmail = "your-github-noreply-address";
```

Review the application list in `modules/apps.nix`, macOS defaults in
`modules/defaults.nix`, and agent settings under `config/`. Configuration files
use `@HOME@` where Home Manager must substitute the selected user's home path.

## Deploy

The target account is `joel.filho` on `aarch64-darwin`.

```bash
# 1. Install Apple's command-line developer tools.
xcode-select --install

# 2. Install multi-user Nix, then load it in this shell.
curl -L https://nixos.org/nix/install | sh -s -- --daemon
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# 3. Clone and validate the configuration.
mkdir -p ~/Work
mkdir -p ~/Work/repos/github.com/JoelFrancisco
git clone https://github.com/JoelFrancisco/nix-darwin-config.git ~/Work/repos/github.com/JoelFrancisco/nix-darwin-config
cd ~/Work/repos/github.com/JoelFrancisco/nix-darwin-config
nix flake check --print-build-logs

# 4. Preserve installer-owned shell files before nix-darwin takes ownership.
test ! -e /etc/bashrc || sudo mv /etc/bashrc /etc/bashrc.before-nix-darwin
test ! -e /etc/zshrc || sudo mv /etc/zshrc /etc/zshrc.before-nix-darwin

# 5. Perform the first switch using nix-darwin's bootstrap command.
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake .#macbook
```

Subsequent rebuilds:

```bash
darwin-rebuild switch --flake ~/Work/repos/github.com/JoelFrancisco/nix-darwin-config#macbook
```

The first activation installs Homebrew packages/casks, removes recognized
launchers from the former mutable AI installation, and runs the best-effort
bootstrap for the remaining mutable tools. It can take a while because GUI
applications are downloaded. Inspect `~/.local/state/ai-tools/bootstrap.log`,
then rerun `ai-tools-update` if a mutable vendor was temporarily unavailable.

## Secrets

No secret value is evaluated by Nix or written to the Nix store. SecretSpec resolves values only when a command/service starts.

1. Open and unlock 1Password, then enable **Settings → Developer → Integrate
   with 1Password CLI**.
2. In the default vault, create a Secure Note named `nix-darwin-config`.
3. Add `OPENROUTER_API_KEY` and a random `CLAUDEX_PROXY_TOKEN` field. Optional
   fields are declared for OpenAI, Anthropic, and Gemini.
4. After creating the Secure Note, SecretSpec can add or update its declared
   fields:

```bash
secretspec set OPENROUTER_API_KEY --file ~/.config/nix-darwin/secretspec.toml --profile personal
secretspec set CLAUDEX_PROXY_TOKEN --file ~/.config/nix-darwin/secretspec.toml --profile personal
```

5. Verify:

```bash
op whoami
secretspec check --file ~/.config/nix-darwin/secretspec.toml --profile personal
```

Change the provider URI in `config/secretspec.toml` if you do not want
1Password's default vault. The Claude proxy token is injected only at runtime;
the generated mode-0600 config and CLIProxyAPI OAuth state remain mutable under
`~/.local/state/cli-proxy-api` and `~/.config/cli-proxy-api/auth` respectively.

## Update policy

The update models are deliberate:

| Tool group | Owner | Default channel | Update mechanism | Rollback |
| --- | --- | --- | --- | --- |
| Claude Code, Codex, OpenCode stable, Executor, SecretSpec | Home Manager | `pinned` | Reviewed flake lock update | Nix generation |
| Reproducible package overrides | Home Manager | `fast-pinned` | Version/hash update followed by flake checks | Nix generation |
| OpenCode 2, Hermes, CLIProxyAPI | Upstream/Homebrew | `latest` exception | Login and four-hour updater | Vendor-specific |
| GUI applications | Homebrew/vendor | Latest | Homebrew and built-in updaters | Vendor-specific |

The AI module exposes `ai.channel` with `pinned`, `fast-pinned`, and `latest`.
The default is `pinned`. `fast-pinned` accepts package overrides through
`ai.fastPinnedPackages`; any tool without an override falls back to the pinned
nixpkgs package. `ai.mutableTools` is the explicit allowlist for exceptions.
The root flake exposes each stable AI package separately, so a package and its
non-interactive version check can be built before updating a machine.

Every four hours and on login, `ai-tools-update` now touches only the selected
mutable exceptions, T3 Code Nightly, Homebrew tools that remain mutable, and
the allow-listed public skills. Selecting `latest` explicitly restores the
vendor installers for the stable AI clients.

No Betha repository, skill, project trust entry, VPN credential, agent history, auth database, or runtime memory is copied into this repository.

## Manual approvals

macOS requires first-launch approval for 1Password integration, Raycast Accessibility, Tailscale and Proton VPN network extensions, notifications, microphone/camera access, and some app login items. Nix can install these apps but cannot safely bypass TCC or system-extension consent.

DaVinci Resolve is intentionally installed from Blackmagic Design rather than
the Mac App Store. Its official download requires vendor registration and an
interactive administrator installer, so it is not managed by Nix or Homebrew.
Download the free macOS installer from the
[official Resolve page](https://www.blackmagicdesign.com/products/davinciresolve).

Command-Space is released from Spotlight and assigned to Raycast. Ghostty is associated with shell scripts and Unix executables; macOS has no single public system-wide “default terminal” setting.

## Checks and VM test

```bash
nix develop -c shellcheck scripts/* tests/*.sh
rg --files -0 -g '*.nix' | xargs -0 nix fmt -- --check
nix flake check --print-build-logs
./tests/vm-test.sh
```

After one successful online provisioning run, `VM_SKIP_NETWORK_UPDATES=1 ./tests/vm-test.sh`
runs the same modules with Homebrew auto-update disabled, two activations,
reboot, and the smoke suite without refresh-only Homebrew and AI network calls.
This is useful during an upstream CDN outage; the default remains online.

The VM test uses a disposable Tart macOS guest, switches the configuration twice, reboots, and runs `tests/smoke-test.sh`. Background agents use the user launchd domain, so the headless test verifies both their generated plists and loaded services. The completed acceptance run is recorded in [`docs/vm-test-report.md`](docs/vm-test-report.md).

macOS guests cannot exercise nested virtualization engines, so the test verifies that OrbStack, Tart, and UTM install; their actual container/VM engines must be smoke-tested on physical hardware. Tailscale's package installs in the guest, but its final automatic GUI launch is unavailable without a GUI bootstrap domain; the activation accepts that post-install error only on Apple's `VirtualMac` platform and only after the app bundle exists.

Rollback remains available through `darwin-rebuild --list-generations` and `darwin-rebuild switch --rollback`.

## License

Released under the MIT License. See [`LICENSE`](LICENSE).
