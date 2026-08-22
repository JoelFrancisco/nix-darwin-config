{ inputs, config, ... }:
let
  user = "joel.filho";
in
{
  flake.darwinConfigurations.macbook = inputs.nix-darwin.lib.darwinSystem {
    specialArgs = { inherit inputs user; };
    modules = [
      inputs.nix-homebrew.darwinModules.nix-homebrew
      inputs.home-manager.darwinModules.home-manager
      config.flake.darwinModules.system
      config.flake.darwinModules.apps
      config.flake.darwinModules.defaults
      config.flake.darwinModules.nosleep
      {
        nix-homebrew = {
          enable = true;
          inherit user;
          enableRosetta = true;
          autoMigrate = true;
          mutableTaps = true;
        };

        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = true;
          backupFileExtension = "before-nix-darwin";
          extraSpecialArgs = { inherit inputs user; };
          users.${user}.imports = [
            config.flake.homeModules.shell
            config.flake.homeModules.editor
            config.flake.homeModules.terminal
            config.flake.homeModules.ai
            config.flake.homeModules.desktop
            config.flake.homeModules.nosleep
          ];
        };
      }
    ];
  };

  perSystem = { pkgs, ... }: {
    formatter = pkgs.nixfmt;
    checks.eval-macbook = config.flake.darwinConfigurations.macbook.system;
    devShells.default = pkgs.mkShell {
      packages = with pkgs; [
        git
        jq
        nixfmt
        shellcheck
      ];
    };
  };
}
