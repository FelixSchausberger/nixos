{
  config,
  lib,
  ...
}: {
  options.modules.system.homelab.ssh = {
    enable = lib.mkEnableOption "Hardened SSH server configuration";
  };

  config = lib.mkIf config.modules.system.homelab.ssh.enable {
    services.openssh = {
      enable = true;

      # Persist host keys across impermanence reboots
      hostKeys = [
        {
          path = "/per/etc/ssh/ssh_host_rsa_key";
          type = "rsa";
          bits = 4096;
        }
        {
          path = "/per/etc/ssh/ssh_host_ed25519_key";
          type = "ed25519";
        }
      ];

      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        MaxAuthTries = 3;
        LoginGraceTime = 30;
        ClientAliveInterval = 120;
        ClientAliveCountMax = 3;
        X11Forwarding = false;
        PrintMotd = false;
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
        ];
        KexAlgorithms = [
          "curve25519-sha256"
          "curve25519-sha256@libssh.org"
          "diffie-hellman-group14-sha256"
        ];
        Macs = [
          "hmac-sha2-256-etm@openssh.com"
          "hmac-sha2-512-etm@openssh.com"
          "umac-128-etm@openssh.com"
        ];
      };
    };

    # Persist SSH host keys (required to maintain stable host identity across reboots)
    systemd.tmpfiles.rules = [
      "d /per/etc/ssh 0755 root root -"
    ];
  };
}
