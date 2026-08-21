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
  # Deploy chain: build -> downgrade-guard -> switch -> validate.
  # nh os switch <path> skips flake evaluation entirely (deploys exactly the guarded
  # closure, so a flake edit between steps cannot cause divergence). The switch runs
  # in the foreground: NixOS switches are atomic and re-runnable, so an SSH drop
  # mid-switch leaves a partially-activated system that a re-run converges — old
  # generation stays bootable. nh escalates to root internally for activation; the
  # store path is resolved first because root cannot follow the /tmp/nh-result
  # symlink across ZFS datasets with posix ACLs (Permission denied on stat).
  # A failed activation keeps the old generation, so switch needs no test pre-step.
  # guard-downgrades.sh blocks deploys/updates that would regress package versions.
  #
  # Lock updates have a single writer: the weekly-updates GitHub Actions
  # workflow (daily cron, on-demand via `update`). Hosts converge to main
  # automatically through comin; `update` triggers CI and restarts comin for
  # immediate convergence. The downgrade guard is mandatory in the deploy
  # path and ALLOW_DOWNGRADE=1 (bulk bypass) is refused; intentional
  # per-package downgrades go through ALLOW_DOWNGRADES or an input pin in
  # flake.nix. Automated comin deployments cannot block, so they report
  # regressions to ntfy instead (modules/system/comin.nix).
  programs.fish.shellAliases = {
    # Build, block regressions, then switch the guarded store path
    # jj status runs first as a non-blocking sanity check (shows untracked files, pending changes)
    # --repository targets the flake dir regardless of cwd
    deploy = "jj --repository $NH_FLAKE status; and nh os build -S -o /tmp/nh-result; and $NH_FLAKE/tools/scripts/guard-downgrades.sh /tmp/nh-result; and nh os switch -d never (readlink -f /tmp/nh-result); and validate-system";
    deploy-offline = "jj --repository $NH_FLAKE status; and nh os build -S -o /tmp/nh-result -- --option substitute false; and $NH_FLAKE/tools/scripts/guard-downgrades.sh /tmp/nh-result; and nh os switch -d never (readlink -f /tmp/nh-result); and validate-system";
    deploy-verbose = "jj --repository $NH_FLAKE status; and NH_LOG=nh=debug nh os build -S -o /tmp/nh-result; and $NH_FLAKE/tools/scripts/guard-downgrades.sh /tmp/nh-result; and nh os switch -d never (readlink -f /tmp/nh-result); and validate-system";

    # Immediate update: dispatch the lock-refresh workflow, wait for the PR
    # to auto-merge, sync onto main, restart comin for instant convergence.
    update = "$NH_FLAKE/tools/scripts/update-system.sh";

    # Utility aliases
    clean = "nh clean all";
    osinfo = "nh os info";
    search = "nh search";
  };
}
