# Test: comin GitOps module produces expected configuration on enabled hosts
{flake, ...}: let
  configs = flake.nixosConfigurations;

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
  };
in {
  desktop = testComin "desktop" configs.desktop.config;
  hp-probook-wsl = testComin "hp-probook-wsl" configs.hp-probook-wsl.config;
  m920q = testComin "m920q" configs.m920q.config;

  # m920q runs the local testing remote instead of the removed auto-push timer.
  m920q_local_remote = let
    remotes = configs.m920q.config.services.comin.remotes;
    byName = name: builtins.head (builtins.filter (r: r.name == name) remotes);
    origin = byName "origin";
    local = byName "local";
  in {
    local_url = local.url;
    local_poll_period = local.poller.period;
    local_main_branch = local.branches.main.name;
    local_testing_branch = local.branches.testing.name;
    local_testing_operation = local.branches.testing.operation;
    origin_main_operation = origin.branches.main.operation;
    origin_testing_disabled = origin.branches.testing.name;
  };
}
