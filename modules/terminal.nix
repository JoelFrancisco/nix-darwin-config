{ ... }:
{
  flake.homeModules.terminal = { pkgs, user, ... }: {
    programs.tmux = {
      enable = true;
      prefix = "C-a";
      baseIndex = 1;
      escapeTime = 10;
      historyLimit = 50000;
      keyMode = "vi";
      mouse = true;
      sensibleOnTop = false;
      terminal = "tmux-256color";
      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = resurrect;
          extraConfig = ''
            set -g @resurrect-strategy-nvim 'session'
            set -g @resurrect-capture-pane-contents 'on'
          '';
        }
        {
          plugin = continuum;
          extraConfig = "set -g @continuum-save-interval '15'";
        }
      ];
      extraConfig = ''
        set -g prefix2 None
        unbind C-b
        bind C-a send-prefix
        bind q source-file ~/.config/tmux/tmux.conf

        bind -T copy-mode-vi v send -X begin-selection
        bind -T copy-mode-vi y send -X copy-selection-and-cancel

        bind h split-window -v -c "#{pane_current_path}"
        bind v split-window -h -c "#{pane_current_path}"
        bind x kill-pane
        bind -n C-M-Left select-pane -L
        bind -n C-M-Right select-pane -R
        bind -n C-M-Up select-pane -U
        bind -n C-M-Down select-pane -D
        bind -n C-M-S-Left resize-pane -L 5
        bind -n C-M-S-Down resize-pane -D 5
        bind -n C-M-S-Up resize-pane -U 5
        bind -n C-M-S-Right resize-pane -R 5

        bind r command-prompt -I "#W" "rename-window -- '%%'"
        bind c new-window -c "#{pane_current_path}"
        bind k kill-window
        bind -n M-1 select-window -t 1
        bind -n M-2 select-window -t 2
        bind -n M-3 select-window -t 3
        bind -n M-4 select-window -t 4
        bind -n M-5 select-window -t 5
        bind -n M-6 select-window -t 6
        bind -n M-7 select-window -t 7
        bind -n M-8 select-window -t 8
        bind -n M-9 select-window -t 9
        bind -n M-Left select-window -t -1
        bind -n M-Right select-window -t +1
        bind -n M-S-Left swap-window -t -1 \; select-window -t -1
        bind -n M-S-Right swap-window -t +1 \; select-window -t +1

        bind R command-prompt -I "#S" "rename-session -- '%%'"
        bind C new-session -c "#{pane_current_path}"
        bind K kill-session
        bind P switch-client -p
        bind N switch-client -n
        bind -n M-Up switch-client -p
        bind -n M-Down switch-client -n

        bind-key "T" run-shell "sesh connect \"$(
          sesh list --icons | fzf-tmux -p 80%,70% \
            --no-sort --ansi --border-label ' sesh ' --prompt '⚡  ' \
            --header '  ^a all ^t tmux ^g configs ^x zoxide ^d tmux kill ^f find' \
            --bind 'tab:down,btab:up' \
            --bind 'ctrl-a:change-prompt(⚡  )+reload(sesh list --icons)' \
            --bind 'ctrl-t:change-prompt(🪟  )+reload(sesh list -t --icons)' \
            --bind 'ctrl-g:change-prompt(⚙️  )+reload(sesh list -c --icons)' \
            --bind 'ctrl-x:change-prompt(📁  )+reload(sesh list -z --icons)' \
            --bind 'ctrl-f:change-prompt(🔎  )+reload(fd -H -d 2 -t d -E .Trash . ~)' \
            --bind 'ctrl-d:execute(tmux kill-session -t {2..})+change-prompt(⚡  )+reload(sesh list --icons)' \
            --preview-window 'right:55%' \
            --preview 'sesh preview {}'
        )\""
        bind-key W run-shell 'sesh window "$(sesh window | fzf-tmux -p 60%,50% --prompt "🪟  ")"'
        bind-key M command-prompt -p "new project (under ~/Work):" "run-shell 'mkp ~/Work/%1 >/dev/null && sesh connect ~/Work/%1'"

        set -ag terminal-overrides ",*:RGB"
        set -g renumber-windows on
        setw -g pane-base-index 1
        set -g focus-events on
        set -g set-clipboard on
        set -g allow-passthrough on
        set -g extended-keys on
        set -g extended-keys-format csi-u
        setw -g aggressive-resize on
        set -g detach-on-destroy off

        set -g status-position top
        set -g status-interval 5
        set -g status-left-length 30
        set -g status-right-length 50
        set -g window-status-separator ""
        setw -g automatic-rename on
        setw -g automatic-rename-format '#{b:pane_current_path}'
        set -g status-style "bg=default,fg=default"
        set -g status-left "#[fg=black,bg=blue,bold] #S #[bg=default] "
        set -g status-right "#[fg=blue]#{?pane_in_mode,COPY ,}#{?client_prefix,PREFIX ,}#[fg=brightblack]#h "
        set -g window-status-format "#[fg=brightblack] #I:#W "
        set -g window-status-current-format "#[fg=blue,bold] #I:#W "
        set -g pane-border-style "fg=brightblack"
        set -g pane-active-border-style "fg=blue"
        set -g message-style "bg=default,fg=blue"
        set -g message-command-style "bg=default,fg=blue"
        set -g mode-style "bg=blue,fg=black"
        setw -g clock-mode-colour blue
      '';
    };

    xdg.configFile."ghostty/config".text = ''
      font-family = JetBrainsMono Nerd Font Mono
      font-size = 16
      font-thicken = true
      theme = Dark+
      window-padding-x = 12
      window-padding-y = 12
      window-decoration = true
      background-opacity = 0.94
      background-blur-radius = 20
      cursor-style = block
      cursor-style-blink = false
      macos-titlebar-style = transparent
      macos-option-as-alt = true
      copy-on-select = clipboard
      confirm-close-surface = false
    '';

    xdg.configFile."herdr/config.toml".text = ''
      onboarding = false
      [theme]
      name = "tokyo-night"
      auto_switch = false
      [terminal]
      default_shell = "/bin/zsh"
      shell_mode = "login"
      new_cwd = "/Users/${user}/Work"
      [update]
      channel = "stable"
      version_check = true
      manifest_check = true
      [keys]
      prefix = "ctrl+a"
      help = "prefix+?"
      settings = "prefix+s"
      detach = "prefix+d"
      reload_config = "prefix+q"
      open_notification_target = "prefix+o"
      workspace_picker = ["prefix+w", "prefix+shift+t"]
      goto = "prefix+g"
      new_workspace = "prefix+shift+c"
      rename_workspace = "prefix+shift+r"
      close_workspace = "prefix+shift+k"
      previous_workspace = ["prefix+shift+p", "alt+up"]
      next_workspace = ["prefix+shift+n", "alt+down"]
      switch_workspace = "prefix+shift+1..9"
      new_tab = "prefix+c"
      rename_tab = "prefix+r"
      close_tab = "prefix+k"
      previous_tab = "alt+left"
      next_tab = "alt+right"
      switch_tab = "alt+1..9"
      split_horizontal = "prefix+h"
      split_vertical = "prefix+v"
      close_pane = "prefix+x"
      focus_pane_left = "ctrl+alt+left"
      focus_pane_down = "ctrl+alt+down"
      focus_pane_up = "ctrl+alt+up"
      focus_pane_right = "ctrl+alt+right"
      resize_mode = "prefix+shift+z"
      zoom = "prefix+z"
      edit_scrollback = "prefix+["
      rename_pane = "prefix+alt+p"
      focus_agent = "prefix+alt+1..9"
      toggle_sidebar = "prefix+b"

      [[keys.command]]
      key = "ctrl+alt+shift+left"
      type = "shell"
      command = '"$HERDR_BIN_PATH" pane resize --pane "$HERDR_ACTIVE_PANE_ID" --direction left --amount 5'
      description = "resize pane left"

      [[keys.command]]
      key = "ctrl+alt+shift+down"
      type = "shell"
      command = '"$HERDR_BIN_PATH" pane resize --pane "$HERDR_ACTIVE_PANE_ID" --direction down --amount 5'
      description = "resize pane down"

      [[keys.command]]
      key = "ctrl+alt+shift+up"
      type = "shell"
      command = '"$HERDR_BIN_PATH" pane resize --pane "$HERDR_ACTIVE_PANE_ID" --direction up --amount 5'
      description = "resize pane up"

      [[keys.command]]
      key = "ctrl+alt+shift+right"
      type = "shell"
      command = '"$HERDR_BIN_PATH" pane resize --pane "$HERDR_ACTIVE_PANE_ID" --direction right --amount 5'
      description = "resize pane right"

      [ui]
      sidebar_width = 18
      sidebar_min_width = 14
      sidebar_max_width = 28
      sidebar_collapsed_mode = "hidden"
      mouse_capture = true
      host_cursor = "native"
      confirm_close = true
      prompt_new_tab_name = false
      pane_borders = true
      pane_gaps = true
      show_agent_labels_on_pane_borders = true
      hide_tab_bar_when_single_tab = true
      agent_panel_sort = "spaces"
      accent = "blue"
      [ui.toast]
      delivery = "terminal"
      delay_seconds = 2
      [ui.toast.clipboard]
      enabled = true
      [ui.sound]
      enabled = false
      [session]
      resume_agents_on_restore = true
      [remote]
      manage_ssh_config = true
      [experimental]
      pane_history = false
      allow_nested = false
      kitty_graphics = false
      [advanced]
      scrollback_limit_bytes = 10000000
    '';
  };
}
