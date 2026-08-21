{ ... }:
{
  flake.darwinModules.system = { pkgs, user, ... }: {
    nixpkgs.hostPlatform = "aarch64-darwin";
    nixpkgs.config.allowUnfree = true;

    system = {
      primaryUser = user;
      stateVersion = 6;
    };

    networking.hostName = "macbook";
    networking.computerName = "Joel's MacBook";

    users.users.${user} = {
      home = "/Users/${user}";
      shell = pkgs.zsh;
    };

    nix = {
      enable = true;
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        auto-optimise-store = true;
        trusted-users = [
          "root"
          user
        ];
      };
      gc = {
        automatic = true;
        interval = {
          Weekday = 7;
          Hour = 3;
          Minute = 0;
        };
        options = "--delete-older-than 30d";
      };
    };

    programs.zsh.enable = true;
    security.pam.services.sudo_local.touchIdAuth = true;

    environment.systemPackages = with pkgs; [
      bat
      coreutils
      curl
      direnv
      eza
      fd
      findutils
      fzf
      gawk
      gh
      git
      gnugrep
      gnupg
      gnused
      jq
      neovim
      nodejs_24
      ripgrep
      rsync
      shellcheck
      tree
      wget
      yq-go
      zoxide
    ];

    environment.variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      PAGER = "less -FR";
    };
  };
}
