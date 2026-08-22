{ ... }:
let
  latestCask = name: {
    inherit name;
    greedy = true;
  };
in
{
  flake.darwinModules.apps = { lib, user, ... }: {
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
    system.activationScripts.postActivation.text = ''
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
        "claude-code@latest"
        "codex"
        "codex-app"
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
        "tailscale-app"
        "telegram"
        "todoist-app"
        "utm"
        "whatsapp"
        "wispr-flow"
        "zed"
        "zoom"
      ];
    };
  };
}
