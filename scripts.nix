{
  config,
  lib,
  ...
}:
with lib; {
  imports = [
    inputs.scripts.nixosModules
  ];

  options = {
    services.scripts.enable = mkEnableOption "Enable custom scripts";

    # Add any configuration options for your Rust project here
    # For example, you might want to pass additional environment variables or parameters to your Rust project.
  };

  config = mkIf (config.services.scripts.enable) {
    environment.systemPackages = [scripts.packages."x86_64-linux"];
  };
}
