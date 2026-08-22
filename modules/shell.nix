{ ... }:
{
  flake.homeModules.shell = { pkgs, user, ... }: {
    home = {
      username = user;
      homeDirectory = "/Users/${user}";
      stateVersion = "25.11";
      sessionPath = [
        "$HOME/.local/bin"
        "$HOME/.opencode/bin"
        "$HOME/.local/share/npm/bin"
      ];
      sessionVariables = {
        CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
        SECRETSPEC_FILE = "$HOME/.config/nix-darwin/secretspec.toml";
        SECRETSPEC_PROFILE = "personal";
        SECRETSPEC_PROVIDER = "onepassword://";
      };
    };

    programs.home-manager.enable = true;
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
    programs.starship = {
      enable = true;
      settings = {
        add_newline = true;
        command_timeout = 2000;
        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };
        directory = {
          style = "bold cyan";
          read_only = " 󰌾";
          truncation_length = 3;
          truncate_to_repo = false;
        };
        git_branch = {
          symbol = " ";
          style = "bold purple";
        };
        git_status.style = "bold red";
        nodejs.symbol = "󰎙 ";
        python.symbol = " ";
        java.symbol = " ";
        golang.symbol = " ";
        rust.symbol = " ";
        docker_context.symbol = " ";
        kubernetes.symbol = "󱃾 ";
        package.symbol = "󰏗 ";
        cmd_duration = {
          min_time = 500;
          format = "took [$duration](bold yellow) ";
        };
        gcloud.disabled = true;
      };
    };
    programs.atuin = {
      enable = true;
      enableZshIntegration = true;
      settings.enter_accept = true;
    };
    programs.zoxide.enable = true;
    programs.fzf = {
      enable = true;
      # Atuin owns Ctrl-R; keep fzf available without shadowing history search.
      historyWidget.command = "";
    };

    programs.git = {
      enable = true;
      settings = {
        init.defaultBranch = "main";
        user = {
          name = "Joel Francisco";
          email = "69012524+JoelFrancisco@users.noreply.github.com";
        };
        pull.rebase = true;
        push.autoSetupRemote = true;
      };
    };

    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;
      shellAliases = {
        n = "nvim";
        gst = "git status";
        gc = "git commit -m";
        gaa = "git add";
        tns = "tmux new-session -s";
        tas = "tmux attach -t";
        tls = "tmux ls";
        tnm = "tmux new-session -s main";
        ccy = "claude --dangerously-skip-permissions";
        codex-yolo = "codex --dangerously-bypass-approvals-and-sandbox";
        oc2 = "opencode2 --standalone";
      };
      initContent = ''
        source ~/.orbstack/shell/init.zsh 2>/dev/null || true

        _aijail_opts=(--ssh --rw-map ~/Work --mask .env --mask .env.local --mask credentials.json)
        jclaude()       { ai-jail "''${_aijail_opts[@]}" claude --dangerously-skip-permissions "$@"; }
        jcodex()        { ai-jail "''${_aijail_opts[@]}" codex --dangerously-bypass-approvals-and-sandbox "$@"; }
        jopencode()     { ai-jail "''${_aijail_opts[@]}" opencode "$@"; }
        jclaude-run()   { ai-jail "''${_aijail_opts[@]}" claude -p --dangerously-skip-permissions "$@"; }
        jcodex-run()    { ai-jail "''${_aijail_opts[@]}" codex exec --dangerously-bypass-approvals-and-sandbox "$@"; }
        jopencode-run() { ai-jail "''${_aijail_opts[@]}" opencode run --dangerously-skip-permissions "$@"; }
        jclaudex()      { ai-jail "''${_aijail_opts[@]}" claudex "$@"; }

        mkp() {
          mkdir -p "$1" && zoxide add "$1" && cd "$1"
        }
      '';
    };

    home.packages = with pkgs; [
      lazygit
      sesh
      tmux
      yazi
    ];
  };
}
