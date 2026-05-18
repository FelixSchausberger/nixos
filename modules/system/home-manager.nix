{inputs, ...}: let
  user = "schausberger";
in {
  imports = [
    inputs.home-manager.nixosModules.default
    inputs.nur.modules.nixos.default
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup-$(date +%Y%m%d-%H%M%S)";
    verbose = false;

    extraSpecialArgs = {
      inherit inputs;
    };

    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops

      {
        home.activation.logActivation = ''
          $DRY_RUN_CMD echo "Home Manager activation started at $(date)"
          $DRY_RUN_CMD echo "   Generation: $newGenPath"

          if [[ ! -v DRY_RUN ]]; then
            echo "$(date): Home Manager activation completed successfully" >> ~/.local/state/home-manager-activation.log
            touch ~/.config/fish/.functions_updated || true
          fi
        '';
      }
    ];
  };

  systemd.services."home-manager-${user}" = {
    after = ["nix-daemon.service"];
    wants = ["nix-daemon.service"];
  };
}
