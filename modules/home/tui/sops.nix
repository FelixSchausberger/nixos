{
  inputs,
  pkgs,
  ...
}: {
  # TEMPORARILY DISABLED - SOPS HOME MANAGER CAUSING BUILD FAILURES
  # imports = [
  #   inputs.sops-nix.homeManagerModules.sops
  # ];

  home.packages = with pkgs; [
    age # Modern encryption tool with small explicit keys
    sops # Simple and flexible tool for managing secrets
  ];

  # TEMPORARILY DISABLED - SOPS CONFIGURATION CAUSING BUILD FAILURES
  # sops = {
  #   age = {
  #     generateKey = false;
  #     keyFile = "/per/system/sops-key.txt";
  #   };

  #   defaultSopsFile = "${inputs.self}/secrets/secrets.json";

  #   # Add this line to set the environment variable
  #   defaultSopsFormat = "json";
  # };

  # Ensure the SOPS_AGE_KEY_FILE environment variable is set
  home.sessionVariables = {
    SOPS_AGE_KEY_FILE = "/per/system/sops-key.txt";
  };
}
