{
  config,
  lib,
  ...
}: let
  wifiSSID = "PrettyFlyForAWiFi";
  hasWifiEnvTemplate = lib.hasAttrByPath ["sops" "templates" "wifi/env" "path"] config;
in {
  config = lib.mkIf config.networking.networkmanager.enable {
    assertions = [
      {
        assertion = hasWifiEnvTemplate;
        message = "wifi.nix requires sops.templates.\"wifi/env\" (provided by modules/system/sops-common.nix)";
      }
    ];

    networking.networkmanager.ensureProfiles = {
      environmentFiles = [
        (
          if hasWifiEnvTemplate
          then config.sops.templates."wifi/env".path
          else "/run/secrets/wifi/env"
        )
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
