{inputs, ...}: {
  imports = [
    inputs.home-manager.nixosModules.default
    inputs.nur.modules.nixos.default
    # inputs.sops-nix.homeManagerModules.sops
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Use timestamped backups to prevent collisions
    backupFileExtension = "backup-$(date +%Y%m%d-%H%M%S)";
    # Enable verbose output for better debugging
    verbose = true;

    extraSpecialArgs = {
      inherit inputs;
    };

    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops

      # Add activation script to improve logging and error detection
      {
        home.activation.logActivation = ''
          $DRY_RUN_CMD echo "🔄 Home Manager activation started at $(date)"
          $DRY_RUN_CMD echo "   Generation: $newGenPath"

          # Create a marker for successful activation
          if [[ ! -v DRY_RUN ]]; then
            echo "$(date): Home Manager activation completed successfully" >> ~/.local/state/home-manager-activation.log
            # Create update marker for fish functions
            touch ~/.config/fish/.functions_updated || true
          fi
        '';
      }
    ];
  };
}
