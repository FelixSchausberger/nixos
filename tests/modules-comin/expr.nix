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

    # Deployment state survives reboots on impermanence hosts; absent where
    # persistence is force-disabled (surface keeps a real ext4 root)
    state_persisted =
      builtins.any (d: (d.directory or "") == "/var/lib/comin")
      ((config.environment.persistence."/per" or {}).directories or []);
  };
in {
  desktop = testComin "desktop" configs.desktop.config;
  portable = testComin "portable" configs.portable.config;
  surface = testComin "surface" configs.surface.config;
  hp-probook-wsl = testComin "hp-probook-wsl" configs.hp-probook-wsl.config;
  m920q = testComin "m920q" configs.m920q.config;

  # Test VM stays manual: no comin, no service
  hp-probook-vmware = rec {
    hostName = "hp-probook-vmware";
    comin_enabled = configs.hp-probook-vmware.config.modules.system.comin.enable or false;
    comin_service_enabled = configs.hp-probook-vmware.config.services.comin.enable or false;
  };
}
