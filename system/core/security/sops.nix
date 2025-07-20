{
  lib,
  pkgs,
  ...
}: {
  # Sopswarden handles sops configuration, but we still need the tools
  environment.systemPackages = with pkgs; [
    age # Modern encryption tool with small explicit keys
    ssh-to-age # Convert ssh private keys in ed25519 format to age keys
    sops # Simple and flexible tool for managing secrets
  ];

  # Override sopswarden's default keyFile location if needed
  sops.age.keyFile = lib.mkForce "/per/system/sops-key.txt";
}
