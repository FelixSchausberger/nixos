# Test: comin GitOps module produces expected configuration on enabled hosts
{flake, ...}: let
  configs = flake.nixosConfigurations;

  # Strip the volatile store hash (changes on every lock update) while keeping
  # the derivation name and path tail, so semantic changes stay visible.
  stripStoreHash = v: let
    m = builtins.match "^/nix/store/[a-z0-9]+-(.*)" (toString v);
  in
    if m != null
    then "/nix/store/<hash>/" + builtins.head m
    else v;

  # Common comin assertions for a host config
  testComin = hostName: config: {
    inherit hostName;

    # Module is enabled
    comin_enabled = config.modules.system.comin.enable;

    # Comin service is enabled
    comin_service_enabled = config.services.comin.enable;

    # Polls the public GitHub main branch
    remote_url = (builtins.head config.services.comin.remotes).url;
    poll_period = (builtins.head config.services.comin.remotes).poller.period;

    # Post-deployment downgrade detection is wired up
    post_deploy_set = config.services.comin.postDeploymentCommand != null;

    # Deployment state survives reboots on impermanence hosts; absent on hosts
    # where persistence is force-disabled (e.g. WSL).
    state_persisted =
      builtins.any (d: (d.directory or "") == "/var/lib/comin")
      ((config.environment.persistence."/per" or {}).directories or []);

    # Auto-push reconciler: only enabled on the development host
    autopush_enabled = config.modules.system.comin.autoPush.enable;
  };
in {
  desktop = testComin "desktop" configs.desktop.config;
  hp-probook-wsl = testComin "hp-probook-wsl" configs.hp-probook-wsl.config;
  m920q = testComin "m920q" configs.m920q.config;

  # m920q-specific reconciler wiring
  m920q_autopush_service =
    stripStoreHash configs.m920q.config.systemd.user.services.comin-autopush.serviceConfig.ExecStart;
  m920q_autopush_interval =
    configs.m920q.config.systemd.user.timers.comin-autopush.timerConfig.OnUnitActiveSec;
}
