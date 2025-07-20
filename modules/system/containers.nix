{
  config,
  lib,
  pkgs,
  hostConfig,
  ...
}: {
  config = lib.mkIf config.modules.system.containers.enable {
    # Enable Docker daemon
    virtualisation.docker.enable = true;

    # Add user to docker group
    users.users.${hostConfig.user}.extraGroups = ["docker"];

    # Install act (GitHub Actions runner) in home packages
    home-manager.users.${hostConfig.user} = {
      home.packages = with pkgs; [
        act # Run your GitHub Actions locally
      ];

      # Add act-check alias
      programs.fish.shellAliases = {
        act-check = "act -W .github/workflows/check.yml";
      };
    };
  };

  options.modules.system.containers = {
    enable = lib.mkEnableOption "container tools (Docker and act)";
  };
}
