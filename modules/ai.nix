{ ... }:
{
  flake.homeModules.ai =
    {
      lib,
      pkgs,
      user,
      ...
    }:
    let
      executable = source: {
        inherit source;
        executable = true;
      };
    in
    {
      home.file = {
        ".local/bin/claudex" = executable ../scripts/claudex;
        ".local/bin/ai-tools-update" = executable ../scripts/ai-tools-update;
        ".local/bin/ai-skills-update" = executable ../scripts/ai-skills-update;
        ".local/bin/t3-nightly-update" = executable ../scripts/t3-nightly-update;
        ".local/bin/ai-mcp-configure" = executable ../scripts/ai-mcp-configure;
        ".local/bin/ai-memory" = executable ../scripts/ai-memory;
        ".local/bin/ai-memory-ensure" = executable ../scripts/ai-memory-ensure;
        ".local/bin/ai-memory-backup" = executable ../scripts/ai-memory-backup;
        ".agents/AGENTS.md".source = ../config/AGENTS.md;
        ".codex/AGENTS.md".source = ../config/AGENTS.md;
        ".codex/config.toml".source = ../config/codex.toml;
        ".claude/CLAUDE.md".source = ../config/CLAUDE.md;
        ".claude/settings.json".text = builtins.toJSON {
          env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
          model = "claude-fable-5[1m]";
          effortLevel = "high";
          autoUpdatesChannel = "latest";
          editorMode = "vim";
          remoteControlAtStartup = true;
          skipAutoPermissionPrompt = true;
          skipDangerousModePermissionPrompt = true;
          skipWorkflowUsageWarning = true;
          teammateMode = "in-process";
          theme = "dark";
          voiceEnabled = true;
          permissions = {
            defaultMode = "auto";
            allow = [
              "Bash(codex exec:*)"
              "Bash(codex review:*)"
            ];
          };
        };
        ".hermes/config.yaml".source = ../config/hermes.yaml;
        ".t3/userdata/settings.json".source = ../config/t3-settings.json;
        ".ai-jail".text = ''
          no_status_bar = true
          no_save_config = true
          private_home = false
        '';
      };

      # Node is a runtime for global AI clients/updaters, not a project toolchain.
      home.packages = [ pkgs.nodejs_24 ];

      xdg.configFile = {
        "nix-darwin/secretspec.toml".source = ../config/secretspec.toml;
        "cli-proxy-api/config.yaml".source = ../config/cli-proxy-api.yaml;
        "opencode/opencode.json".source = ../config/opencode.json;
      };

      home.activation.prepareAiState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p \
          "$HOME/.executor/logs" \
          "$HOME/.config/ai-memory" \
          "$HOME/.config/cli-proxy-api/auth" \
          "$HOME/.local/state/ai-tools" \
          "$HOME/.local/state/cli-proxy-api"
      '';

      home.activation.bootstrapAiTools =
        lib.hm.dag.entryAfter
          [
            "prepareAiState"
            "linkGeneration"
          ]
          ''
            if [[ -z "''${DRY_RUN:-}" ]]; then
              "$HOME/.local/bin/ai-tools-update" >"$HOME/.local/state/ai-tools/bootstrap.log" 2>&1 || true
              "$HOME/.local/bin/ai-mcp-configure" >>"$HOME/.local/state/ai-tools/bootstrap.log" 2>&1 || true
            fi
          '';

      launchd.agents = {
        executor = {
          enable = true;
          domain = "user";
          config = {
            Label = "sh.executor.daemon";
            ProgramArguments = [
              "/Users/${user}/.local/bin/executor"
              "daemon"
              "run"
              "--foreground"
              "--port"
              "4789"
              "--hostname"
              "127.0.0.1"
            ];
            EnvironmentVariables = {
              EXECUTOR_DATA_DIR = "/Users/${user}/.executor";
              EXECUTOR_SCOPE_DIR = "/Users/${user}/.executor";
              EXECUTOR_SUPERVISED = "1";
              PATH = "/Users/${user}/.local/bin:/opt/homebrew/bin:/usr/bin:/bin";
            };
            WorkingDirectory = "/Users/${user}/.executor";
            RunAtLoad = true;
            KeepAlive = {
              SuccessfulExit = false;
            };
            ProcessType = "Background";
            StandardOutPath = "/Users/${user}/.executor/logs/daemon.log";
            StandardErrorPath = "/Users/${user}/.executor/logs/daemon.error.log";
          };
        };

        ai-memory-watchdog = {
          enable = true;
          domain = "user";
          config = {
            Label = "com.joel.ai-memory-watchdog";
            ProgramArguments = [ "/Users/${user}/.local/bin/ai-memory-ensure" ];
            EnvironmentVariables = {
              AI_MEMORY_ENSURE_START_DOCKER = "1";
              PATH = "/Users/${user}/.orbstack/bin:/opt/homebrew/bin:/usr/bin:/bin";
            };
            RunAtLoad = true;
            StartInterval = 300;
            StandardOutPath = "/Users/${user}/Library/Logs/ai-memory-watchdog.log";
            StandardErrorPath = "/Users/${user}/Library/Logs/ai-memory-watchdog.log";
          };
        };

        ai-memory-backup = {
          enable = true;
          domain = "user";
          config = {
            Label = "com.joel.ai-memory-backup";
            ProgramArguments = [ "/Users/${user}/.local/bin/ai-memory-backup" ];
            StartCalendarInterval = {
              Hour = 12;
              Minute = 30;
            };
            StandardOutPath = "/Users/${user}/Library/Logs/ai-memory-backup.log";
            StandardErrorPath = "/Users/${user}/Library/Logs/ai-memory-backup.log";
          };
        };

        ai-tools-latest = {
          enable = true;
          domain = "user";
          config = {
            Label = "com.joel.ai-tools-latest";
            ProgramArguments = [ "/Users/${user}/.local/bin/ai-tools-update" ];
            StartCalendarInterval = {
              Hour = 4;
              Minute = 15;
            };
            StandardOutPath = "/Users/${user}/.local/state/ai-tools/update.log";
            StandardErrorPath = "/Users/${user}/.local/state/ai-tools/update.log";
          };
        };

      };
    };
}
