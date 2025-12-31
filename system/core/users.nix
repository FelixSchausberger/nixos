{
  inputs,
  config,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
in {
  # Enable fish shell system-wide
  programs.fish.enable = true;

  users = {
    mutableUsers = false;
    users = {
      root = {
        # Enable root account for emergency access with hardcoded password
        # Uses hardcoded hash instead of sops to prevent lockout if sops fails
        hashedPassword = "$6$w4WluBt5QyBKBzLp$eDywK0Z2aDBc95bdXQBum6uj6fTAcpCgA2yT0H2i09iQrhFshQOKeyCcjcIUYQo7AHQ5Eyv4eT.ooBvhPyqDR1";
      };

      "${defaults.system.user}" = {
        isNormalUser = true;
        description = defaults.personalInfo.name;
        extraGroups = ["fuse" "networkmanager" "input" "video" "render" "wheel" "dialout"];
        hashedPasswordFile = config.sops.secrets."private/password-hash".path;
        group = defaults.system.user;
        shell = pkgs.fish;
      };
    };

    groups.${defaults.system.user} = {};
  };
}
