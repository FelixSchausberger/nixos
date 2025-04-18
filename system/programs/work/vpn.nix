{
  config,
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

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
      auth SHA256
      float
      reneg-sec 3660
      nobind
      mute-replay-warnings

      dhcp-option DOMAIN magazino.eu
    '';
    updateResolvConf = true;
    autoStart = false;
  };

  sops.secrets = {
    "vpn/auth" = {
      owner = "root";
      mode = "0400";
    };
    "vpn/ca.crt" = {
      owner = "root";
      mode = "0444";
    };
    "vpn/client.crt" = {
      owner = "root";
      mode = "0444";
    };
    "vpn/key" = {
      owner = "root";
      mode = "0400";
      path = "/etc/openvpn/magazino/client.pem";
    };
  };

  environment.systemPackages = [
    pkgs.gnused # GNU sed, a batch stream editor
  ];

  # Create a systemd service that will format the key properly before OpenVPN starts
  systemd.services."format-vpn-key" = {
    description = "Format OpenVPN key with proper PEM headers";
    wantedBy = ["openvpn-magazinoVPN.service"];
    before = ["openvpn-magazinoVPN.service"];
    after = ["sops-nix.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Only add headers if they don't already exist
      if ! grep -q "BEGIN RSA PRIVATE KEY" ${config.sops.secrets."vpn/key".path}; then
        # Create a temporary file with the proper PEM format
        TEMP_KEY=$(mktemp)
        echo "-----BEGIN RSA PRIVATE KEY-----" > $TEMP_KEY
        cat ${config.sops.secrets."vpn/key".path} >> $TEMP_KEY
        echo "-----END RSA PRIVATE KEY-----" >> $TEMP_KEY

        # Replace the original key with the formatted one
        cat $TEMP_KEY > ${config.sops.secrets."vpn/key".path}
        rm $TEMP_KEY

        # Ensure proper permissions
        chmod 0400 ${config.sops.secrets."vpn/key".path}
        chown root:root ${config.sops.secrets."vpn/key".path}
      fi
    '';
  };
}
