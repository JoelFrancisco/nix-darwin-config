#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/claudex-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
export CLAUDEX_PROXY_TOKEN="runtime-test-value"
export CLAUDEX_PROXY_URL="http://127.0.0.1:8317"
export CLAUDE_BIN="$test_root/fake-claude"
mkdir -p "$HOME/.config/cli-proxy-api"
cp "$repo_root/config/cli-proxy-api.json" \
  "$HOME/.config/cli-proxy-api/config.template.json"

cat >"$test_root/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$CLAUDE_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ -z "${CLAUDEX_PROXY_TOKEN:-}" ]]
[[ "$ANTHROPIC_AUTH_TOKEN" == "runtime-test-value" ]]
[[ "$ANTHROPIC_BASE_URL" == "http://127.0.0.1:8317" ]]
EOF
chmod +x "$test_root/curl" "$CLAUDE_BIN"
export PATH="$test_root:$PATH"

"$repo_root/scripts/claudex"

runtime_config="$HOME/.local/state/cli-proxy-api/config.json"
jq -e '.host == "127.0.0.1"' "$runtime_config" >/dev/null
jq -e '."auth-dir" == $auth_dir' \
  --arg auth_dir "$HOME/.config/cli-proxy-api/auth" "$runtime_config" >/dev/null
jq -e '."api-keys" == ["runtime-test-value"]' "$runtime_config" >/dev/null
if [[ "$(uname -s)" == "Darwin" ]]; then
  config_mode="$(/usr/bin/stat -f '%Lp' "$runtime_config")"
else
  config_mode="$(stat -c '%a' "$runtime_config")"
fi
[[ "$config_mode" == "600" ]]
[[ ! -e "$HOME/.local/state/cli-proxy-api/lock" ]]

echo "claudex runtime configuration test passed"
