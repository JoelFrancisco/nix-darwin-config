#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/ai-tools-update-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
mkdir -p "$HOME/.local/bin" "$HOME/.local/state/ai-tools"
calls="$test_root/calls"

write_stub() {
  local name="$1"
  shift
  printf '#!/usr/bin/env bash\n%s\n' "$*" >"$HOME/.local/bin/$name"
  chmod +x "$HOME/.local/bin/$name"
}

# Stub bodies intentionally defer expansion until the generated script runs.
# shellcheck disable=SC2016
write_stub curl '
output=""
url=""
while (($#)); do
  case "$1" in
    -o) output="$2"; shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
printf "curl %s\\n" "$url" >>"$AI_TOOLS_TEST_CALLS"
printf '\''#!/usr/bin/env bash\nmkdir -p "$HOME/.opencode/bin"\nprintf "#!/usr/bin/env bash\\nexit 0\\n" >"$HOME/.opencode/bin/opencode2"\nchmod +x "$HOME/.opencode/bin/opencode2"\n'\'' >"$output"
chmod +x "$output"'
# shellcheck disable=SC2016
write_stub brew 'printf "brew %s\\n" "$*" >>"$AI_TOOLS_TEST_CALLS"'
# shellcheck disable=SC2016
write_stub npm 'printf "npm %s\\n" "$*" >>"$AI_TOOLS_TEST_CALLS"; exit 99'
write_stub ai-skills-update 'exit 0'
write_stub t3-nightly-update 'exit 0'

export AI_TOOLS_TEST_CALLS="$calls"
AI_TOOLS_CHANNEL=pinned AI_TOOLS_MUTABLE_TOOLS=opencode2 \
  "$repo_root/scripts/ai-tools-update"

grep -Fx 'curl https://opencode.ai/v2/install' "$calls"
if grep -Eq 'claude\.ai|chatgpt\.com/codex|https://opencode\.ai/install|^npm ' "$calls"; then
  echo "pinned updater attempted to mutate a Nix-owned tool" >&2
  exit 1
fi
test -L "$HOME/.local/bin/opencode2"

echo "AI tools updater ownership test passed"
