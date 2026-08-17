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
  # Deploy chain: build -> downgrade-guard -> detached switch -> validate.
  # nh os switch <path> skips flake evaluation entirely (deploys exactly the guarded
  # closure, so a flake edit between steps cannot cause divergence). The switch itself
  # runs as a systemd oneshot (nixos-deploy.service), so a network timeout or SSH
  # disconnect cannot kill it mid-flight and leave the box half-deployed; instead of
  # dropping the connection, the daemons that own the link (networkd, resolved,
  # tailscaled, adguardhome) are deferred to the nightly maintenance window.
  # A failed activation keeps the old generation, so switch needs no test pre-step.
  # guard-downgrades.sh blocks deploys/updates that would regress package versions.
  programs.fish.shellAliases = {
    # Build, block regressions, then switch atomically under systemd
    # jj status runs first as a non-blocking sanity check (shows untracked files, pending changes)
    # --repository targets the flake dir regardless of cwd
    deploy = "jj --repository $NH_FLAKE status; and nh os build -S -o /tmp/nh-result; and $NH_FLAKE/tools/scripts/guard-downgrades.sh /tmp/nh-result; and sudo systemctl start --wait nixos-deploy; and validate-system";
    deploy-offline = "jj --repository $NH_FLAKE status; and nh os build -S -o /tmp/nh-result -- --option substitute false; and $NH_FLAKE/tools/scripts/guard-downgrades.sh /tmp/nh-result; and sudo systemctl start --wait nixos-deploy; and validate-system";
    deploy-verbose = "jj --repository $NH_FLAKE status; and NH_LOG=nh=debug nh os build -S -o /tmp/nh-result; and $NH_FLAKE/tools/scripts/guard-downgrades.sh /tmp/nh-result; and sudo systemctl start --wait nixos-deploy; and validate-system; and journalctl -u nixos-deploy -n 50 --no-pager";

    # Update flake inputs, build, guard against downgrades, then switch the guarded store path
    update = "nh os build --update -o /tmp/nh-result; and $NH_FLAKE/tools/scripts/guard-downgrades.sh /tmp/nh-result; and sudo systemctl start --wait nixos-deploy; and validate-system";

    # Utility aliases
    clean = "nh clean all";
    osinfo = "nh os info";
    search = "nh search";
  };
}
