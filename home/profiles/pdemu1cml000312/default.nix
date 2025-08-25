{
  imports = [
    ../shared.nix
    ./hyprland.nix
    ../../../modules/home/profiles/features.nix
    ../../../modules/home/work
  ];

  # Feature-based configuration for work laptop
  features = {
    development = {
      enable = true;
      languages = ["nix" "python" "go"];
    };

    work = {
      enable = true;
      aws = true;
      vpn = true;
    };
  };
}
