#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/ai-tools-path-test.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT

export HOME="$test_root/home"
nix_bin="$HOME/.nix-profile/bin"
mutable_opencode="$HOME/.opencode/bin"
mutable_brew="$test_root/homebrew/bin"
mkdir -p "$nix_bin" "$mutable_opencode" "$mutable_brew"

for executable in "$nix_bin/opencode" "$nix_bin/secretspec" "$mutable_opencode/opencode" "$mutable_brew/secretspec"; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$executable"
  chmod +x "$executable"
done

profile_extra="$(nix eval --raw \
  "path:$repo_root#darwinConfigurations.macbook.config.home-manager.users.joel.programs.zsh.profileExtra")"

PATH="$mutable_opencode:$mutable_brew:$nix_bin:/usr/bin:/bin" \
  PROFILE_EXTRA="$profile_extra" /bin/zsh -dfc '
    eval "$PROFILE_EXTRA"
    test "$(command -v opencode)" = "$HOME/.nix-profile/bin/opencode" || exit 1
    test "$(command -v secretspec)" = "$HOME/.nix-profile/bin/secretspec" || exit 1
    case ":$PATH:" in
      *":$HOME/.opencode/bin:"*|*":$HOME/.local/share/npm/bin:"*) exit 1 ;;
    esac
  '

echo "AI tools PATH ownership test passed"
