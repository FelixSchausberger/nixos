# Container runtime profile for Docker-based workflows on selected hosts.
# Optimizes startup behavior and daemon defaults for development and homelab use.
{
  config,
  lib,
  pkgs,
  hostConfig,
  ...
}: {
  options.modules.system.containers = {
    enable = lib.mkEnableOption "container tools (Docker and act)";
  };

  config = lib.mkIf config.modules.system.containers.enable {
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
      tmpfiles.rules = [
        "d /etc/docker 0755 root root - -"
        "d /etc/docker/certs.d 0755 root root - -"
        "d /etc/docker/certs.d/registry-1.docker.io 0755 root root - -"
        "d /etc/docker/certs.d/index.docker.io 0755 root root - -"
        "d /etc/docker/certs.d/docker.io 0755 root root - -"
        "d /etc/docker/certs.d/auth.docker.io 0755 root root - -"
        "d /etc/docker/certs.d/production.cloudflare.docker.com 0755 root root - -"
        "L+ /etc/docker/certs.d/ca-certificates.crt - - - - ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "L+ /etc/docker/certs.d/ca.pem - - - - ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "L+ /etc/docker/certs.d/registry-1.docker.io/ca.crt - - - - ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "L+ /etc/docker/certs.d/index.docker.io/ca.crt - - - - ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "L+ /etc/docker/certs.d/docker.io/ca.crt - - - - ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "L+ /etc/docker/certs.d/auth.docker.io/ca.crt - - - - ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "L+ /etc/docker/certs.d/production.cloudflare.docker.com/ca.crt - - - - ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "L+ /etc/ssl/certs/ca-certificates.crt - - - - ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        "L+ /etc/ssl/certs/ca-bundle.crt - - - - ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      ];

      # Prepares act runner environment with NixOS certificates.
      # Disabled at boot — run manually: systemctl start act-cert-setup
      services.act-cert-setup = {
        description = "Prepare act containers with proper certificate configuration";
        wantedBy = lib.mkForce [];
        path = with pkgs; [coreutils];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "root";
        };
        script = ''
          mkdir -p /etc/act-certificates /usr/local/share/ca-certificates
          ln -sf ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt /etc/act-certificates/ca-certificates.crt
          chmod 755 /etc/act-certificates
          chmod 644 /etc/act-certificates/ca-certificates.crt || true
        '';
      };
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
      home.packages = with pkgs; [act];

      programs.fish.shellAliases = {
        act-check = "DOCKER_HOST=unix:///var/run/docker.sock DOCKER_TLS_VERIFY=0 act -W .github/workflows/check.yml --pull=false";
        act-debug = "DOCKER_HOST=unix:///var/run/docker.sock DOCKER_TLS_VERIFY=0 act -W .github/workflows/check.yml --verbose --pull=false";
      };

      home.sessionVariables = {
        DOCKER_HOST = "unix:///var/run/docker.sock";
        GOPROXY = lib.mkDefault "direct";
      };
    };
  };
}
