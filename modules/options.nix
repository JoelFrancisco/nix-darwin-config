{ lib, ... }:
{
  options.flake = {
    darwinModules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = "Dendritic nix-darwin feature modules.";
    };
    homeModules = lib.mkOption {
      type = lib.types.lazyAttrsOf lib.types.raw;
      default = { };
      description = "Dendritic Home Manager feature modules.";
    };
  };
}
