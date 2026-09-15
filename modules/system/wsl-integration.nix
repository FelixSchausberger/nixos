# WSL-specific integration layer for Windows edge cases and service behavior.
# Isolates Linux-on-WSL quirks from bare-metal host modules.
{
  config,
  lib,
  ...
}: {
  options.modules.system.wsl-integration = {
    enable = lib.mkEnableOption "WSL Windows integration features";
  };

  config = lib.mkIf config.modules.system.wsl-integration.enable {
    # WSL has no virtual consoles — mask vconsole to prevent udev-triggered failures
    systemd.services.systemd-vconsole-setup.enable = lib.mkForce false;

    # systemd-resolved not needed; WSL manages /etc/resolv.conf in NAT mode
    services.resolved.enable = lib.mkForce false;

    # WSL terminates without clean systemd shutdown, which corrupts persistent journals.
    # Volatile storage avoids corruption and is appropriate since WSL state is ephemeral.
    services.journald.settings.Journal.Storage = "volatile";
  };
}
