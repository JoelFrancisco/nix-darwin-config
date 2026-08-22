#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"

failures=0
check() {
  if "$@"; then printf 'ok  %s\n' "$*"; else printf 'FAIL %s\n' "$*" >&2; failures=$((failures + 1)); fi
}

for command_name in git gh nvim tmux fd rg zoxide direnv starship secretspec herdr tart \
  ai-jail cliproxyapi claude codex opencode opencode2 executor hermes; do
  check command -v "$command_name"
done

for path in \
  "$HOME/.config/ghostty/config" \
  "$HOME/.config/tmux/tmux.conf" \
  "$HOME/.config/herdr/config.toml" \
  "$HOME/.config/nvim/init.lua" \
  "$HOME/.config/nvim/lua/config/lazy.lua" \
  "$HOME/.config/opencode/opencode.json" \
  "$HOME/.config/nix-darwin/secretspec.toml" \
  "$HOME/.codex/config.toml" \
  "$HOME/.claude/CLAUDE.md" \
  "$HOME/.agents/AGENTS.md" \
  "$HOME/.local/bin/nosleep"; do
  check test -e "$path"
done

for app in \
  "1Password.app" "Bruno.app" "Claude.app" "Codex.app" "Cursor.app" \
  "Discord.app" "Ghostty.app" "Google Chrome.app" "Helium.app" "LocalSend.app" \
  "Obsidian.app" "OrbStack.app" "ProtonVPN.app" "Raycast.app" "Spotify.app" \
  "Tailscale.app" "Telegram.app" "Todoist.app" "UTM.app" "WhatsApp.app" \
  "Wispr Flow.app" "zoom.us.app"; do
  check test -d "/Applications/$app"
done

if [[ "${SMOKE_SKIP_NETWORK_BOOTSTRAP:-0}" != 1 ]]; then
  check test -d "$HOME/Applications/T3 Code (Nightly).app"
fi
check defaults read com.raycast.macos raycastGlobalHotkey
check test -f "$HOME/Library/LaunchAgents/sh.executor.daemon.plist"
check test -f "$HOME/Library/LaunchAgents/com.joel.ai-memory-watchdog.plist"

check launchctl print "user/$(id -u)/sh.executor.daemon"
check launchctl print "user/$(id -u)/com.joel.ai-memory-watchdog"

((failures == 0)) || { echo "$failures smoke checks failed" >&2; exit 1; }
echo "all smoke checks passed"
