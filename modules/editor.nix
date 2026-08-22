{ ... }:
{
  flake.homeModules.editor =
    {
      lib,
      pkgs,
      ...
    }:
    {
      home.packages = with pkgs; [
        stylua
        tree-sitter
      ];

      programs.neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
        withNodeJs = true;
        withPython3 = true;
        withRuby = false;
      };

      xdg.configFile = {
        "nvim/init.lua".source = ../config/nvim/init.lua;
        "nvim/.neoconf.json".source = ../config/nvim/neoconf.json;
        "nvim/stylua.toml".source = ../config/nvim/stylua.toml;
        "nvim/lua/config/autocmds.lua".source = ../config/nvim/lua/config/autocmds.lua;
        "nvim/lua/config/keymaps.lua".source = ../config/nvim/lua/config/keymaps.lua;
        "nvim/lua/config/lazy.lua".source = ../config/nvim/lua/config/lazy.lua;
        "nvim/lua/config/options.lua".source = ../config/nvim/lua/config/options.lua;
        "nvim/lua/plugins/example.lua".source = ../config/nvim/lua/plugins/example.lua;
      };

      # LazyVim updates its metadata and lockfile at runtime. Seed metadata on
      # a fresh machine, but leave runtime state writable for :Lazy sync.
      home.activation.seedLazyVimState = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        if [[ ! -e "$HOME/.config/nvim/lazyvim.json" ]]; then
          run ${pkgs.coreutils}/bin/install -m 0644 \
            ${../config/nvim/lazyvim.json} "$HOME/.config/nvim/lazyvim.json"
        fi
      '';
    };
}
