#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/ai-tools-migrate-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
mkdir -p \
  "$HOME/.local/bin" \
  "$HOME/.local/share/claude/versions" \
  "$HOME/.codex/packages/standalone/current/bin" \
  "$HOME/.opencode/bin" \
  "$HOME/.local/lib/node_modules/executor/bin"

ln -s "$HOME/.local/share/claude/versions/2.1.0" "$HOME/.local/bin/claude"
ln -s "$HOME/.codex/packages/standalone/current/bin/codex" "$HOME/.local/bin/codex"
ln -s "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"
ln -s "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode1"
ln -s ../lib/node_modules/executor/bin/executor "$HOME/.local/bin/executor"
ln -s "$HOME/custom/claude" "$HOME/.local/bin/unknown-claude"
ln -s "$HOME/.opencode/bin/opencode2" "$HOME/.local/bin/opencode2"

AI_TOOLS_BREW_BIN=/usr/bin/false AI_TOOLS_CHANNEL=pinned \
  "$repo_root/scripts/ai-tools-migrate"

for removed in claude codex opencode opencode1 executor; do
  test ! -L "$HOME/.local/bin/$removed"
done
test -L "$HOME/.local/bin/unknown-claude"
test -L "$HOME/.local/bin/opencode2"

AI_TOOLS_BREW_BIN=/usr/bin/false AI_TOOLS_CHANNEL=pinned \
  "$repo_root/scripts/ai-tools-migrate"

ln -s "$HOME/custom/codex" "$HOME/.local/bin/codex"
AI_TOOLS_BREW_BIN=/usr/bin/false AI_TOOLS_CHANNEL=pinned \
  "$repo_root/scripts/ai-tools-migrate"
test -L "$HOME/.local/bin/codex"

echo "AI tools migration test passed"
