# macOS VM acceptance report

- Host test date: 2026-08-21 (America/Sao_Paulo)
- Guest image: `ghcr.io/cirruslabs/macos-tahoe-base:latest`
- Guest OS: macOS Tahoe 26.6.2 (25G83), Apple Silicon
- VM: `nix-darwin-config-test`, 120 GB disk
- Result: passed

## Exercised flow

1. Copied the exact local checkout into the Tart guest.
2. Evaluated and built `darwinConfigurations.macbook` with Nix flakes.
3. Applied the configuration as the declared `joel.filho` primary user.
4. Installed the Nix, Homebrew, GUI, AI, shell, and launchd declarations.
5. Rebooted macOS.
6. Applied the same configuration a second time to exercise idempotency.
7. Ran `ai-tools-update` and `tests/smoke-test.sh` as `joel.filho`.

The smoke suite verified the required CLI commands, managed configuration files,
application bundles, Raycast hotkey preference, T3 Code Nightly bundle, and the
loaded Executor and AI-memory launch agents. The run ended with:

```text
VM activation and smoke tests passed on nix-darwin-config-test (192.168.64.9)
```

## VM-only limitations

- OrbStack, Tart, and UTM are installed but their nested virtualization engines
  cannot be exercised inside a macOS virtual machine.
- Tailscale's signed package installs its app and CLI, then attempts to launch
  its GUI from a package post-install script. A headless Tart guest rejects that
  launch with launchd error 125. The activation tolerates this only when the
  platform identifies as `VirtualMac` and `/Applications/Tailscale.app` exists.
- macOS TCC, system-extension approvals, account sign-ins, and 1Password CLI
  integration remain first-login actions on physical hardware.
