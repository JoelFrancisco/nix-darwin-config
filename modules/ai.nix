{ inputs, ... }:
let
  packageSet = pkgs: {
    claude-code = pkgs.claude-code;
    codex = pkgs.codex;
    opencode = pkgs.opencode;
    executor = pkgs.callPackage ../packages/executor.nix { };
    secretspec = pkgs.secretspec;
  };
in
{
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      aiPackages = packageSet pkgs;
    in
    {
      packages = aiPackages;
      checks.ai-tools =
        pkgs.runCommand "ai-tools-smoke-check"
          {
            nativeBuildInputs = builtins.attrValues aiPackages;
          }
          ''
            export HOME="$TMPDIR/home"
            export XDG_CONFIG_HOME="$HOME/.config"
            export XDG_STATE_HOME="$HOME/.local/state"
            mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
            claude --version
            codex --version
            opencode --version
            executor --version
            executor daemon run --help >/dev/null
            secretspec --version
            touch "$out"
          '';
    };

  flake.homeModules.ai =
    {
      config,
      lib,
      pkgs,
      user,
      offlineTest,
      ...
    }:
    let
      cfg = config.ai;
      executable = source: {
        inherit source;
        executable = true;
      };
      withHome =
        source: builtins.replaceStrings [ "@HOME@" ] [ "/Users/${user}" ] (builtins.readFile source);
      codexConfig = pkgs.writeText "codex-config.toml" (withHome ../config/codex.toml);
      pinnedPackages = packageSet pkgs;
      fastPinnedPackages = pinnedPackages // cfg.fastPinnedPackages;
      selectedPackages =
        if cfg.channel == "latest" then
          { }
        else if cfg.channel == "fast-pinned" then
          fastPinnedPackages
        else
          pinnedPackages;
      stablePackageNames = [
        "claude-code"
        "codex"
        "opencode"
        "executor"
        "secretspec"
      ];
      executorProgram =
        if cfg.channel == "latest" then
          "/Users/${user}/.local/bin/executor"
        else
          lib.getExe selectedPackages.executor;
    in
    {
      options.ai = {
        channel = lib.mkOption {
          type = lib.types.enum [
            "pinned"
            "fast-pinned"
            "latest"
          ];
          default = "pinned";
          description = ''
            Ownership policy for stable AI tools. "pinned" uses this flake's
            nixpkgs, "fast-pinned" overlays explicitly supplied hashed packages,
            and "latest" delegates stable tools to their upstream installers.
          '';
        };

        fastPinnedPackages = lib.mkOption {
          type = lib.types.attrsOf lib.types.package;
          default = { };
          description = ''
            Reproducible package overrides used by the fast-pinned channel.
            Missing tools fall back to the pinned nixpkgs package set.
          '';
        };

        mutableTools = lib.mkOption {
          type = lib.types.listOf (
            lib.types.enum [
              "opencode2"
              "hermes"
              "cliproxyapi"
            ]
          );
          default = [
            "opencode2"
            "hermes"
            "cliproxyapi"
          ];
          description = "Explicit allowlist of AI tools that remain mutable upstream exceptions.";
        };
      };

      config = {
        assertions = [
          {
            assertion = lib.all (name: builtins.elem name stablePackageNames) (
              builtins.attrNames cfg.fastPinnedPackages
            );
            message = "ai.fastPinnedPackages only accepts: ${lib.concatStringsSep ", " stablePackageNames}";
          }
        ];

        home.file = {
          ".local/bin/claudex" = executable ../scripts/claudex;
          ".local/bin/ai-tools-update" = executable ../scripts/ai-tools-update;
          ".local/bin/ai-tools-migrate" = executable ../scripts/ai-tools-migrate;
          ".local/bin/ai-skills-update" = executable ../scripts/ai-skills-update;
          ".local/bin/t3-nightly-update" = executable ../scripts/t3-nightly-update;
          ".local/bin/ai-mcp-configure" = executable ../scripts/ai-mcp-configure;
          ".local/bin/ai-memory" = executable ../scripts/ai-memory;
          ".local/bin/ai-memory-ensure" = executable ../scripts/ai-memory-ensure;
          ".local/bin/ai-memory-backup" = executable ../scripts/ai-memory-backup;
          ".agents/AGENTS.md".source = ../config/AGENTS.md;
          ".codex/AGENTS.md".source = ../config/AGENTS.md;
          ".claude/CLAUDE.md".source = ../config/CLAUDE.md;
          ".claude/settings.json".text = builtins.toJSON {
            env = {
              CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
            }
            // lib.optionalAttrs (cfg.channel != "latest") { DISABLE_AUTOUPDATER = "1"; };
            model = "claude-fable-5[1m]";
            effortLevel = "high";
            autoUpdates = cfg.channel == "latest";
            autoUpdatesChannel = if cfg.channel == "latest" then "latest" else "stable";
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
          ".t3/userdata/settings.json".text = withHome ../config/t3-settings.json;
          ".ai-jail".text = ''
            no_status_bar = true
            no_save_config = true
            private_home = false
          '';
        };

        home.packages =
          (lib.optionals (cfg.channel != "latest") (map (name: selectedPackages.${name}) stablePackageNames))
          ++ lib.optional (cfg.channel == "latest") pkgs.nodejs_24;

        home.sessionVariables = lib.optionalAttrs (cfg.channel != "latest") {
          # Claude's native build otherwise installs a mutable copy in the background.
          DISABLE_AUTOUPDATER = "1";
        };

        xdg.configFile = {
          "nix-darwin/secretspec.toml".source = ../config/secretspec.toml;
          "cli-proxy-api/config.template.json".source = ../config/cli-proxy-api.json;
          "opencode/opencode.json".text = withHome ../config/opencode.json;
        };

        home.activation.prepareAiState = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
          run mkdir -p \
            "$HOME/.codex" \
            "$HOME/.executor/logs" \
            "$HOME/.config/ai-memory" \
            "$HOME/.config/cli-proxy-api/auth" \
            "$HOME/.local/state/ai-tools" \
            "$HOME/.local/state/cli-proxy-api"
          run install -m 600 ${codexConfig} "$HOME/.codex/config.toml"
        '';

        home.activation.bootstrapAiTools =
          lib.hm.dag.entryAfter
            [
              "prepareAiState"
              "linkGeneration"
            ]
            (
              if offlineTest then
                ''
                  AI_TOOLS_CHANNEL=${lib.escapeShellArg cfg.channel} \
                    "$HOME/.local/bin/ai-tools-migrate"
                ''
              else
                ''
                  if [[ -z "''${DRY_RUN:-}" ]]; then
                    export AI_TOOLS_CHANNEL=${lib.escapeShellArg cfg.channel}
                    export AI_TOOLS_MUTABLE_TOOLS=${lib.escapeShellArg (lib.concatStringsSep " " cfg.mutableTools)}
                    "$HOME/.local/bin/ai-tools-migrate" >"$HOME/.local/state/ai-tools/bootstrap.log" 2>&1
                    "$HOME/.local/bin/ai-tools-update" >>"$HOME/.local/state/ai-tools/bootstrap.log" 2>&1 || true
                    "$HOME/.local/bin/ai-mcp-configure" >>"$HOME/.local/state/ai-tools/bootstrap.log" 2>&1 || true
                  fi
                ''
            );

        launchd.agents = {
          executor = {
            enable = true;
            domain = "user";
            config = {
              Label = "sh.executor.daemon";
              ProgramArguments = [
                executorProgram
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
              }
              // lib.optionalAttrs (cfg.channel != "latest") { DISABLE_AUTOUPDATER = "1"; };
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
            enable = !offlineTest;
            domain = "user";
            config = {
              Label = "com.joel.ai-tools-latest";
              ProgramArguments = [ "/Users/${user}/.local/bin/ai-tools-update" ];
              EnvironmentVariables.PATH = "/Users/${user}/.local/bin:/Users/${user}/.nix-profile/bin:/etc/profiles/per-user/${user}/bin:/run/current-system/sw/bin:/opt/homebrew/bin:/usr/bin:/bin";
              EnvironmentVariables.AI_TOOLS_CHANNEL = cfg.channel;
              EnvironmentVariables.AI_TOOLS_MUTABLE_TOOLS = lib.concatStringsSep " " cfg.mutableTools;
              RunAtLoad = true;
              StartInterval = 14400;
              StandardOutPath = "/Users/${user}/.local/state/ai-tools/update.log";
              StandardErrorPath = "/Users/${user}/.local/state/ai-tools/update.log";
            };
          };

        };
      };
    };
}
