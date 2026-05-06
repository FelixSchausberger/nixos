{
  config,
  lib,
  ...
}: let
  wifiSSID = "PrettyFlyForAWiFi";
in {
  config = lib.mkIf config.networking.networkmanager.enable {
    networking.networkmanager.ensureProfiles = {
      environmentFiles = [
        config.sops.templates."wifi/env".path
      ];
      profiles.${wifiSSID} = {
        connection = {
          id = wifiSSID;
          type = "wifi";
          autoconnect = true;
        };
        wifi = {
          ssid = wifiSSID;
          mode = "infrastructure";
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = "$WIFI_PSK";
        };
        ipv4.method = "auto";
      };
    };
  };
}
