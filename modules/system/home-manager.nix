{
  inputs,
  lib,
  pkgs,
  ...
}: let
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
    # Disable release check — HM tracks nixos-unstable, not a fixed release
    extraSpecialArgs = {
      inherit inputs;
    };

    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops

      # Disable Nixpkgs release version check (HM and nixpkgs both track unstable)
      {home.enableNixpkgsReleaseCheck = false;}

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
    serviceConfig = {
      TimeoutStartSec = lib.mkDefault "5m";
      ExecStartPre = [
        "${pkgs.bash}/bin/bash -c 'for i in $(seq 1 60); do systemctl is-active --quiet nix-daemon.service 2>/dev/null && exit 0; sleep 1; done; exit 1'"
      ];
    };
  };
}
