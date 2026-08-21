{ ... }:
{
  flake.darwinModules.services = { user, ... }: {
    environment.etc."sudoers.d/nosleep-pmset" = {
      text = ''
        # nosleep snapshots/restores only macOS power-management keys.
        ${user} ALL = (root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1, /usr/bin/pmset -b *, /usr/bin/pmset -c *
      '';
    };
  };
}
