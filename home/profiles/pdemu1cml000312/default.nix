{
  imports = [
    ../shared.nix
    ./hyprland.nix
    ../../../modules/home/profiles/features.nix
  ];

  # Feature-based configuration for work laptop
  features = {
    development = {
      enable = true;
      languages = ["nix" "python" "go"];
    };
  };
}
