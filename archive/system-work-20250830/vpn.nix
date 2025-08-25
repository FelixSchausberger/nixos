{
  config,
  pkgs,
  ...
}: {
  sops.secrets = {
    "vpn/ca.crt" = {};
    "vpn/client.crt" = {};
    "vpn/key" = {};
    "vpn/auth" = {};
  };
  users.users.openvpn = {
    isSystemUser = true;
    group = "openvpn";
  };
  users.groups.openvpn = {};

  services.openvpn.servers.magazinoVPN = {
    config = ''
      dev tun
      client
      proto tcp-client
      ca ${config.sops.secrets."vpn/ca.crt".path}
      cert ${config.sops.secrets."vpn/client.crt".path}
      key ${config.sops.secrets."vpn/key".path}
      remote-cert-eku "TLS Web Server Authentication"
      remote sec.magazino.eu 443
      persist-key
      persist-tun
      verb 3
      mute 20
      keepalive 10 60
      cipher AES-256-CBC
      data-ciphers AES-256-CBC
      auth SHA256
      float
      reneg-sec 3660
      nobind
      auth-user-pass ${config.sops.secrets."vpn/auth".path}
      mute-replay-warnings

      dhcp-option DOMAIN magazino.eu
    '';
    updateResolvConf = true;
    autoStart = false;
  };

  environment.systemPackages = [
    pkgs.gnused # GNU sed, a batch stream editor
  ];
}
