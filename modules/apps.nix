{ ... }:
let
  latestCask = name: {
    inherit name;
    greedy = true;
  };
in
{
  flake.darwinModules.apps = { lib, user, ... }: {
    # A migrated Homebrew prefix can retain its previous owner's mutable lock
    # directory. Hand only that state directory to the declared primary user
    # before nix-darwin invokes brew bundle.
    system.activationScripts.homebrew.text = lib.mkOrder 750 ''
      if [ -d /opt/homebrew/var/homebrew ]; then
        /usr/sbin/chown -R ${user}:admin /opt/homebrew/var/homebrew
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
        "anomalyco/tap"
        "akitaonrails/tap"
        "cirruslabs/cli"
      ];

      brews = [
        "akitaonrails/tap/ai-jail"
        "cliproxyapi"
        "duti"
        "herdr"
        "hermes-agent"
        "secretspec"
        "cirruslabs/cli/tart"
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
