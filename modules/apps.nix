{ ... }:
let
  latestCask = name: {
    inherit name;
    greedy = true;
  };
in
{
  flake.darwinModules.apps = { ... }: {
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
        "cirruslabs/cli"
      ];

      brews = [
        "ai-jail"
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
