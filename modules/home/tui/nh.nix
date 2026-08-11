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
  # guard-downgrades.sh blocks deploys/updates that would regress package versions
  programs.fish.shellAliases = {
    # Test configuration, then auto-switch if successful
    # jj status runs first as a non-blocking sanity check (shows untracked files, pending changes)
    # --repository targets the flake dir regardless of cwd
    deploy = "jj --repository $NH_FLAKE status; and nh os build -S -o /tmp/nh-result; and $NH_FLAKE/tools/scripts/guard-downgrades.sh /tmp/nh-result; and nh os test -S; and nh os switch -S; and validate-system";
    deploy-offline = "jj --repository $NH_FLAKE status; and nh os build -S -o /tmp/nh-result -- --option substitute false; and $NH_FLAKE/tools/scripts/guard-downgrades.sh /tmp/nh-result; and nh os test -S -- --option substitute false; and nh os switch -S -- --option substitute false; and validate-system";
    deploy-verbose = "jj --repository $NH_FLAKE status; and NH_LOG=nh=debug nh os build -S -o /tmp/nh-result; and $NH_FLAKE/tools/scripts/guard-downgrades.sh /tmp/nh-result; and NH_LOG=nh=debug nh os test -S; and NH_LOG=nh=debug nh os switch -S; and validate-system";

    # Update inputs, test configuration, then auto-switch if successful
    update = "nh os build --update -o /tmp/nh-result; and $NH_FLAKE/tools/scripts/guard-downgrades.sh /tmp/nh-result; and nh os test -S; and nh os switch -S; and validate-system";

    # Utility aliases
    clean = "nh clean all";
    osinfo = "nh os info";
    search = "nh search";
  };
}
