# Test: SSH module produces hardened configuration
{flake, ...}: let
  # Desktop is the primary host with modules.system.ssh.enable
  inherit (flake.nixosConfigurations.desktop) config;
in {
  # Module is enabled
  ssh_module_enabled = config.modules.system.ssh.enable;

  # OpenSSH service is enabled
  openssh_enabled = config.services.openssh.enable;

  # Hardened settings
  password_auth_disabled = config.services.openssh.settings.PasswordAuthentication == false;
  kbd_interactive_disabled = config.services.openssh.settings.KbdInteractiveAuthentication == false;
  permit_root_login_no = config.services.openssh.settings.PermitRootLogin == "no";
  x11_forwarding_disabled = config.services.openssh.settings.X11Forwarding == false;
  max_auth_tries = config.services.openssh.settings.MaxAuthTries;
  login_grace_time = config.services.openssh.settings.LoginGraceTime;

  # Host keys configured at hardened paths
  has_rsa_key = builtins.any (k: k.path or "" == "/per/etc/ssh/ssh_host_rsa_key") config.services.openssh.hostKeys;
  has_ed25519_key = builtins.any (k: k.path or "" == "/per/etc/ssh/ssh_host_ed25519_key") config.services.openssh.hostKeys;

  # Tmpfiles rule for ssh directory
  has_ssh_tmpfiles = builtins.any (rule: builtins.match "d /per/etc/ssh.*" rule != null) config.systemd.tmpfiles.rules;
}
