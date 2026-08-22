{ ... }:
let
  latestCask = name: {
    inherit name;
    greedy = true;
  };
in
{
  flake.darwinModules.apps =
    {
      lib,
      user,
      offlineTest,
      ...
    }:
    {
      # A migrated Homebrew prefix can retain its previous owner's mutable
      # directories. Hand those to the declared primary user after nix-homebrew
      # installs its managed code, but before nix-darwin invokes brew bundle.
      system.activationScripts.homebrew.text = lib.mkOrder 750 ''
        for brew_dir in Cellar Caskroom Frameworks bin etc include lib opt sbin share var; do
          if [ -e "/opt/homebrew/$brew_dir" ]; then
            /usr/sbin/chown -R ${user}:admin "/opt/homebrew/$brew_dir"
          fi
        done
        if [ -d /opt/homebrew/var/homebrew/locks ]; then
          /bin/chmod -R u+rwX /opt/homebrew/var/homebrew
          /usr/bin/sudo -u ${user} -H /usr/bin/touch /opt/homebrew/var/homebrew/locks/.nix-darwin-write-test
          /bin/rm -f /opt/homebrew/var/homebrew/locks/.nix-darwin-write-test
        fi
      '';

      # Homebrew 6's Bundle fetch subprocess loses trust for a dependency of an
      # already-present Tart tap. Install Tart immediately after Bundle with an
      # explicit, minimal trust set until that upstream migration bug is fixed.
      system.activationScripts.postActivation.text =
        if offlineTest then
          ''
            echo "Skipping Homebrew post-activation updates for offline VM regression"
          ''
        else
          ''
            if [ -x /opt/homebrew/bin/brew ]; then
              /usr/bin/sudo -u ${user} -H /opt/homebrew/bin/brew trust --tap anomalyco/tap
              /usr/bin/sudo -u ${user} -H /opt/homebrew/bin/brew trust --tap akitaonrails/tap
              /usr/bin/sudo -u ${user} -H /opt/homebrew/bin/brew trust --tap cirruslabs/cli
              /usr/bin/sudo -u ${user} -H /opt/homebrew/bin/brew trust --formula cirruslabs/cli/softnet
              if /usr/bin/sudo -u ${user} -H /opt/homebrew/bin/brew list --formula cirruslabs/cli/tart >/dev/null 2>&1; then
                /usr/bin/sudo -u ${user} -H /opt/homebrew/bin/brew upgrade --formula cirruslabs/cli/tart
              else
                /usr/bin/sudo -u ${user} -H /opt/homebrew/bin/brew install --formula cirruslabs/cli/tart
              fi

              # These casks contain signed Apple packages. Homebrew 6 launches their
              # installers on a separate pseudo-terminal, which cannot reuse the
              # darwin-rebuild sudo ticket. Fetch (and checksum) as the user, then
              # stage the package in a root-only directory before installing it.
              install_pkg_cask() {
                cask="$1"
                app_path="$2"
                version="$(/usr/bin/sudo -u ${user} -H /opt/homebrew/bin/brew info --json=v2 --cask "$cask" | /run/current-system/sw/bin/jq -r '.casks[0].version')"
                version_file="/var/db/nix-darwin-$cask.version"
                installed_version="$(/bin/cat "$version_file" 2>/dev/null || true)"

                if [ "$installed_version" != "$version" ] || [ ! -d "$app_path" ]; then
                  /usr/bin/sudo -u ${user} -H /opt/homebrew/bin/brew fetch --cask "$cask"
                  source_pkg="$(/usr/bin/sudo -u ${user} -H /opt/homebrew/bin/brew --cache --cask "$cask")"
                  stage_dir="$(/usr/bin/mktemp -d "/var/tmp/nix-darwin-$cask.XXXXXX")"
                  /bin/chmod 700 "$stage_dir"
                  /bin/cp "$source_pkg" "$stage_dir/$cask.pkg"
                  /usr/sbin/chown root:wheel "$stage_dir/$cask.pkg"
                  /bin/chmod 600 "$stage_dir/$cask.pkg"
                  if ! /usr/sbin/installer -pkg "$stage_dir/$cask.pkg" -target /; then
                    if /usr/sbin/ioreg -rd1 -c IOPlatformExpertDevice | /usr/bin/grep -q VirtualMac \
                      && [ -d "$app_path" ]; then
                      echo "warning: $cask installed but its GUI post-install launch is unavailable in this macOS VM" >&2
                    else
                      /bin/rm -f "$stage_dir/$cask.pkg"
                      /bin/rmdir "$stage_dir"
                      return 1
                    fi
                  fi
                  /bin/rm -f "$stage_dir/$cask.pkg"
                  /bin/rmdir "$stage_dir"
                  /usr/bin/printf '%s\n' "$version" > "$version_file"
                fi
              }

              install_pkg_cask tailscale-app "/Applications/Tailscale.app"
              install_pkg_cask zoom "/Applications/zoom.us.app"
            fi
          '';

      homebrew = {
        enable = true;
        global.autoUpdate = true;
        onActivation = {
          autoUpdate = true;
          upgrade = true;
          # Preserve unrelated packages already owned by this Mac.
          cleanup = "none";
        };

        taps = [
          {
            name = "anomalyco/tap";
            trusted = true;
          }
          {
            name = "akitaonrails/tap";
            trusted = true;
          }
          {
            name = "cirruslabs/cli";
            trusted = true;
          }
        ];

        brews = [
          "akitaonrails/tap/ai-jail"
          "cliproxyapi"
          "duti"
          "herdr"
          "hermes-agent"
          "secretspec"
        ];

        casks = map latestCask [
          "1password"
          "1password-cli"
          "bruno"
          "claude"
          "chatgpt"
          "cursor"
          "discord"
          "font-jetbrains-mono-nerd-font"
          "ghostty"
          "google-chrome"
          "helium-browser"
          "localsend"
          "obsidian"
          "orbstack"
          "protonvpn"
          "raycast"
          "spotify"
          "telegram"
          "todoist-app"
          "utm"
          "whatsapp"
          "wispr-flow"
          "zed"
        ];
      };
    };
}
