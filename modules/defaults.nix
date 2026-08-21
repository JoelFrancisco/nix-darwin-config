{ ... }:
{
  flake.darwinModules.defaults = { user, ... }: {
    system.defaults = {
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleShowAllExtensions = true;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
      };
      dock = {
        autohide = true;
        mru-spaces = false;
        show-recents = false;
        tilesize = 48;
      };
      finder = {
        AppleShowAllFiles = true;
        FXDefaultSearchScope = "SCcf";
        FXPreferredViewStyle = "Nlsv";
        ShowPathbar = true;
        ShowStatusBar = true;
      };
      screencapture.location = "/Users/${user}/Pictures/Screenshots";
      trackpad.Clicking = true;
    };

    # Free Command-Space from Spotlight. Raycast's private preference is applied
    # idempotently by `configure-desktop`; its UI still verifies the hotkey.
    system.activationScripts.postActivation.text = ''
      mkdir -p /Users/${user}/Pictures/Screenshots
      chown ${user}:staff /Users/${user}/Pictures/Screenshots
      /usr/bin/su - ${user} -c '/usr/bin/defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 "<dict><key>enabled</key><false/></dict>"' || true
    '';
  };
}
