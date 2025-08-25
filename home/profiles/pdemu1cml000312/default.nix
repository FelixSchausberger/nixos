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
      languages = ["nix" "python" "javascript" "go"];
    };

    work = {
      enable = true;
      aws = true;
      vpn = true;
    };

    media = {
      enable = true;
      streaming = true;
    };

    productivity = {
      enable = true;
      office = true;
      notes = true;
      tasks = true;
    };
  };
}
