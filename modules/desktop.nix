{ ... }:
{
  flake.homeModules.desktop = { lib, ... }: {
    home.file.".local/bin/configure-desktop" = {
      source = ../scripts/configure-desktop;
      executable = true;
    };

    home.activation.configureDesktop = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [[ -z "''${DRY_RUN:-}" ]]; then
        "$HOME/.local/bin/configure-desktop" || true
      fi
    '';
  };
}
