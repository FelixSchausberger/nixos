{
  services.openssh = {
    enable = true;

    hostKeys = [
      {
        path = "/per/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
      }
      {
        path = "/per/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  system.activationScripts.sshdKeyPermissions = ''
    chmod 600 /per/etc/ssh/ssh_host_*_key
    chmod 700 /per/etc/ssh
    chmod 755 /per/etc
  '';
}
