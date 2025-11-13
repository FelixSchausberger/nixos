_: {
  # NH - Yet another Nix CLI helper
  # Modern replacement for nixos-rebuild with better UX and output formatting
  programs.nh = {
    enable = true;

    # Enable automatic cleanup of build results
    clean.enable = true;
    clean.extraArgs = "--keep-since 4d --keep 3";
  };

  # Set NH_FLAKE environment variable to point to the NixOS configuration directory
  home.sessionVariables = {
    NH_FLAKE = "/per/etc/nixos";
  };

  # NH (Nix Helper) aliases for Fish shell
  # Automatic deployment: test first, then switch if test succeeds
  # Uses cached build results, so second step is nearly instant
  programs.fish.shellAliases = {
    # Test configuration, then auto-switch if successful
    deploy = "nh os test; and nh os switch; and validate-system";
    deploy-offline = "nh os test -- --option substitute false; and nh os switch -- --option substitute false; and validate-system";
    deploy-verbose = "NH_LOG=nh=debug nh os test; and NH_LOG=nh=debug nh os switch; and validate-system";

    # Update inputs, test configuration, then auto-switch if successful
    update = "nh os test --update; and nh os switch";

    # Utility aliases
    clean = "nh clean all";
    osinfo = "nh os info";
    search = "nh search";
  };
}
