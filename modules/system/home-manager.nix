{inputs, ...}: {
  imports = [
    inputs.home-manager.nixosModules.default
    inputs.nur.modules.nixos.default
    # inputs.sops-nix.homeManagerModules.sops
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    backupFileExtension = "backup";

    # Ensure home-manager activates properly during system rebuild
    verbose = true;

    extraSpecialArgs = {
      inherit inputs;
    };

    sharedModules = [
      inputs.sops-nix.homeManagerModules.sops

      # Module to ensure fish functions reload properly
      {
        programs.fish = {
          loginShellInit = ''
            # Reload fish functions after home-manager activation
            if test -n "$HOME_MANAGER_GENERATION"
              for func_file in ~/.config/fish/functions/*.fish
                if test -f "$func_file"
                  source "$func_file"
                end
              end
            end
          '';

          # Ensure functions are available immediately
          interactiveShellInit = ''
            # Auto-reload functions if they've been updated
            set -l functions_dir ~/.config/fish/functions
            if test -d "$functions_dir"
              for func_file in "$functions_dir"/*.fish
                if test -f "$func_file" -a "$func_file" -nt ~/.config/fish/.last_reload 2>/dev/null
                  source "$func_file"
                end
              end
              touch ~/.config/fish/.last_reload
            end
          '';
        };

        # Create activation script to reload current shell sessions
        home.activation.reloadShellFunctions = inputs.home-manager.lib.hm.dag.entryAfter ["writeBoundary"] ''
          # Create a reload marker for running shells to detect
          $DRY_RUN_CMD touch ~/.config/fish/.functions_updated || true
        '';
      }
    ];
  };
}
