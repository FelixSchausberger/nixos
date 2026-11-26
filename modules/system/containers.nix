# Container runtime profile for Docker-based workflows on selected hosts.
# Optimizes startup behavior and daemon defaults for development and homelab use.
{
  config,
  lib,
  pkgs,
  hostConfig,
  ...
}: let
  # Single source for the CA bundle the registry symlinks below point at.
  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
in {
  options.modules.system.containers = {
    enable = lib.mkEnableOption "container tools (Docker)";
  };

  config = lib.mkIf config.modules.system.containers.enable {
    assertions = [
      {
        assertion = config.modules.system.ssl.enable;
        message = "modules.system.containers.enable requires modules.system.ssl.enable because Docker environment uses modules.system.ssl.helpers.dockerEnv";
      }
    ];

    virtualisation.docker = {
      enable = true;
      enableOnBoot = false; # Start on-demand for boot performance

      daemon.settings = {
        "storage-driver" = "overlay2";
        "log-driver" = "json-file";
        "log-opts" = {
          "max-size" = "10m";
          "max-file" = "3";
        };
        "dns" = [
          "8.8.8.8"
          "8.8.4.4"
        ];
        "userland-proxy" = false;
        "live-restore" = false;
      };
    };

    systemd = {
      sockets.docker.wantedBy = lib.mkForce [];

      services.docker = {
        wantedBy = lib.mkForce [];
        # The assertion above guarantees modules.system.ssl.enable, so the
        # helper is always defined here.
        environment =
          config.modules.system.ssl.helpers.dockerEnv
          // {
            DOCKER_TLS_VERIFY = "0"; # Unix socket — no TLS
            GOPROXY = "direct";
            DOCKER_CONFIG = "/etc/docker";
          };
      };

      # Certificate directories and registry CA links — created declaratively
      # before Docker starts (tmpfiles runs before most services).
      # The system CA paths (/etc/ssl/certs/*) are deliberately absent: an
      # `L+` rule there clobbers security.pki's merged bundle at every boot,
      # bypassing security.pki.certificateFiles/certificates.
      tmpfiles.rules = [
        "d /etc/docker 0755 root root - -"
        "d /etc/docker/certs.d 0755 root root - -"
        "d /etc/docker/certs.d/registry-1.docker.io 0755 root root - -"
        "d /etc/docker/certs.d/index.docker.io 0755 root root - -"
        "d /etc/docker/certs.d/docker.io 0755 root root - -"
        "d /etc/docker/certs.d/auth.docker.io 0755 root root - -"
        "d /etc/docker/certs.d/production.cloudflare.docker.com 0755 root root - -"
        "L+ /etc/docker/certs.d/ca-certificates.crt - - - - ${caBundle}"
        "L+ /etc/docker/certs.d/ca.pem - - - - ${caBundle}"
        "L+ /etc/docker/certs.d/registry-1.docker.io/ca.crt - - - - ${caBundle}"
        "L+ /etc/docker/certs.d/index.docker.io/ca.crt - - - - ${caBundle}"
        "L+ /etc/docker/certs.d/docker.io/ca.crt - - - - ${caBundle}"
        "L+ /etc/docker/certs.d/auth.docker.io/ca.crt - - - - ${caBundle}"
        "L+ /etc/docker/certs.d/production.cloudflare.docker.com/ca.crt - - - - ${caBundle}"
      ];
    };

    environment.variables = {
      DOCKER_HOST = "unix:///var/run/docker.sock";
    };

    users.users.${hostConfig.user}.extraGroups = ["docker"];

    environment.systemPackages = with pkgs; [
      docker-compose
      openssl
      curl
    ];

    home-manager.users.${hostConfig.user} = {
      home.sessionVariables = {
        DOCKER_HOST = "unix:///var/run/docker.sock";
        GOPROXY = lib.mkDefault "direct";
      };
    };
  };
}
