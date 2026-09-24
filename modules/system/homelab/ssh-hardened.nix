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

      # Socket activation: no sshd daemon between connections. Avoids restarting an
      # active sshd during a switch (no dropped sessions) and tightens attack surface.
      startWhenNeeded = true;

      # Persist host keys across impermanence reboots
      hostKeys = lib.mkForce [
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
        AcceptEnv = ["COLORTERM"];
        Ciphers = [
          "chacha20-poly1305@openssh.com"
          "aes256-gcm@openssh.com"
          "aes128-gcm@openssh.com"
        ];
        # mlkem768x25519-sha256 is the OpenSSH >= 10.0 default hybrid: it can
        # only be stronger than X25519, never weaker, and without it every
        # OpenSSH >= 10.1 client prints the store-now-decrypt-later warning.
        # The classical entries remain for clients that predate it.
        KexAlgorithms = [
          "mlkem768x25519-sha256"
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
