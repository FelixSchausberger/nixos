{pkgs, ...}: {
  home.packages = with pkgs; [
    impala # TUI for managing WiFi connections
    iwd # Modern WiFi daemon (alternative to wpa_supplicant)
  ];
}
