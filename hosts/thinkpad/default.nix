{
  imports = [
    ./boot-zfs.nix
    ../../system/programs/gnome.nix
    ./hardware-configuration.nix
  ];

  # Enable 32-bit support for Direct Rendering Infrastructure (DRI)
  # hardware = {
  #   graphics = {
  #     enable32Bit = true;
  #   };

  #   keyboard.qmk.enable = true;
  # };

  # services.openvpn.servers = {
  #   magazinoVPN = {
  #     # config = ''config /etc/openvpn/magazino.conf '';
  #     config = "config /etc/openvpn/magazino/magazino.ovpn";
  #     authUserPass = {
  #       password = config.sops.secrets."vpn/password".path;
  #       username = config.sops.secrets."vpn/username".path;
  #     };
  #   };
  # };
}
