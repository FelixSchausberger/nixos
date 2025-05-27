# system/default.nix
{
  # Standard system modules applicable to all regularly used hosts
  # (desktop, surface, pdemu1cml000312, portable).
  standardSystemModules = [
    ./core          # Core configurations: users, security policies.
    ./network.nix   # Network configuration.
    ./nix           # Nix settings, including shared substituters.
                    # (./nix/default.nix should import ./nix/nixpkgs.nix and ./nix/shared/substituters.nix)
    ./hardware      # Common hardware support: audio, bluetooth, graphics.
    ./programs/shared # Shared applications and system-level Home Manager settings.
  ];

  # Additive modules specific to the gaming desktop.
  # Can be expanded with system-level gaming utilities if necessary.
  gamingSystemModules = [
    # e.g., ./programs/gaming (if such a module is created)
  ];
}
