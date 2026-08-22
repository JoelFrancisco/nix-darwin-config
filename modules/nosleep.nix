{ ... }:
{
  flake.darwinModules.nosleep = { user, ... }: {
    environment.etc."sudoers.d/nosleep-pmset".text = ''
      # nosleep snapshots/restores only macOS power-management keys.
      ${user} ALL = (root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -b *, /usr/bin/pmset -c *
    '';
  };

  flake.homeModules.nosleep = { user, ... }: {
    home.file = {
      ".local/bin/nosleep" = {
        source = ../scripts/nosleep;
        executable = true;
      };
      ".local/bin/nosleep-auto-off" = {
        source = ../scripts/nosleep-auto-off;
        executable = true;
      };
    };

    launchd.agents.nosleep-auto-off = {
      enable = true;
      domain = "user";
      config = {
        Label = "com.joel.nosleep-auto-off";
        ProgramArguments = [ "/Users/${user}/.local/bin/nosleep-auto-off" ];
        ProcessType = "Background";
        StartCalendarInterval =
          map
            (time: {
              Hour = builtins.elemAt time 0;
              Minute = builtins.elemAt time 1;
            })
            [
              [
                20
                30
              ]
              [
                21
                0
              ]
              [
                21
                30
              ]
              [
                22
                0
              ]
              [
                22
                30
              ]
              [
                23
                0
              ]
              [
                23
                30
              ]
            ];
        StandardOutPath = "/Users/${user}/.local/state/nosleep/auto-off.log";
        StandardErrorPath = "/Users/${user}/.local/state/nosleep/auto-off.log";
      };
    };
  };
}
