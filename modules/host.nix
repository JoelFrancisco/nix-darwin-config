{ inputs, config, ... }:
let
  user = "joel";
  gitName = "Joel Francisco";
  gitEmail = "69012524+JoelFrancisco@users.noreply.github.com";
  mkMacbook =
    {
      offlineTest ? false,
      extraModules ? [ ],
    }:
    inputs.nix-darwin.lib.darwinSystem {
      specialArgs = {
        inherit
          inputs
          user
          gitName
          gitEmail
          offlineTest
          ;
      };
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
            extraSpecialArgs = {
              inherit
                inputs
                user
                gitName
                gitEmail
                offlineTest
                ;
            };
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
      ]
      ++ extraModules;
    };
in
{
  flake.darwinConfigurations = {
    macbook = mkMacbook { };
    macbook-offline-test = mkMacbook {
      offlineTest = true;
      extraModules = [
        ({ lib, ... }: {
          homebrew.onActivation.autoUpdate = lib.mkForce false;
        })
      ];
    };
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
