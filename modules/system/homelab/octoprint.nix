# OctoPrint control stack for the Prusa MK3S+ attached to this host over USB:
# loopback-bound web API consumed by Home Assistant, web UI on a Tailscale
# Serve port, serial device pinned by-id.
#
# Architecture:
#   - The printer stays its factory 8-bit Einsy machine: it has no radio, so
#     zigbee/matter paths do not apply, and OctoPrint is the serial and web
#     gateway. The device path is the systemd by-id entry (it contains the
#     printer's serial number, printed on its frame), so a re-plug cannot move
#     the printer to a different tty number; the upstream nixpkgs unit already
#     puts the daemon into the dialout group these nodes use, so no udev rule.
#   - serial.autoconnect stays false: OctoPrint opens the device only when a
#     client connects it, never at service start, so deploys and reboots never
#     touch a print running from the printer's own LCD.
#   - Loopback bind only: Home Assistant polls 127.0.0.1 from this host, and
#     the UI is tailnet-only behind Tailscale Serve. Serve clients arrive from
#     the tailnet subnet, which ipCheck otherwise warns about as a remote
#     address, so the subnet is trusted here.
#   - The state dir is created under the /per mount source so the ordering
#     against the impermanence bind mounts cannot shadow it (the same
#     workaround as jellyfin.nix), while OctoPrint itself keeps the module
#     default /var/lib/octoprint behind the bind mount.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.octoprint;
  hl = config.modules.system.homelab;

  tailscaleServe = import ../../../lib/tailscale-serve.nix {inherit pkgs;};

  # Ports already claimed by other Tailscale Serve frontends on this host.
  servePorts = [
    hl.zellijWeb.httpsPort
    hl.opencodeWeb.httpsPort
    hl.homepage.httpsPort
    hl.monitoring.prometheusHttpsPort
    hl.vaultwarden.httpsPort
    hl.smartHome.httpsPort
    hl.smartHome.frontendHttpsPort
  ];
in {
  options.modules.system.homelab.octoprint = {
    enable = lib.mkEnableOption "OctoPrint for the MK3S+ printer attached over USB";

    port = lib.mkOption {
      type = lib.types.port;
      default = inputs.self.lib.homelabPorts.octoprint;
      description = "OctoPrint loopback HTTP port";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8451;
      description = "Tailscale Serve HTTPS port for the OctoPrint UI";
    };

    serialDevice = lib.mkOption {
      type = lib.types.str;
      default = "/dev/serial/by-id/usb-Prusa_Research__prusa3d.com__Original_Prusa_i3_MK3_CZPX2321X004XK87560-if00";
      description = ''
        Serial device of the MK3S+ printer USB line (USB-B port on the
        Einsy board to a host USB-A port). Defaults to the systemd by-id
        path so a re-plug never changes the device number.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.httpsPort != cfg.port && !(builtins.elem cfg.httpsPort servePorts);
        message = "modules.system.homelab.octoprint.httpsPort must differ from cfg.port and the other Tailscale Serve fronts (zellij-web, opencode-web, homepage, prometheus, vaultwarden, home assistant, zigbee2mqtt frontend)";
      }
    ];

    services.octoprint = {
      enable = true;
      # Only the loopback and Tailscale-serve fronts reach the API; the nixpkgs
      # module applies server.host only when non-null, and OctoPrint's default
      # bind is 0.0.0.0.
      host = "127.0.0.1";
      inherit (cfg) port;
      # With autoconnect off the service never opens the serial device on its
      # own: deploys, reboots and restarts are invisible to the printer until a
      # client (HA action or the UI) connects it.
      extraConfig = {
        serial = {
          port = cfg.serialDevice;
          autoconnect = false;
        };
        server.ipCheck.trustedSubnets = ["100.64.0.0/10"];
      };
    };

    # Home Assistant RSS alone is in the gigabyte range; cap OctoPrint the same
    # way so a runaway plugin cannot evict immich/jellyfin on the 16 GB host
    # (the same protection pattern as jellyfin.nix/smart-home.nix).
    systemd.services = {
      octoprint.serviceConfig = {
        MemoryMax = "800M";
        MemoryHigh = "600M";
      };

      tailscale-serve-octoprint = lib.mkIf hl.caddyProxy.enable (
        tailscaleServe {
          name = "tailscale-serve-octoprint";
          description = "Expose the OctoPrint UI via Tailscale Serve";
          inherit (cfg) httpsPort;
          upstreamPort = cfg.port;
          after = ["octoprint.service"];
          wants = ["octoprint.service"];
        }
      );
    };

    # State directories survive reboots on the impermanence host. The tmpfiles
    # rule creates the dir under the mount source directly so the ordering
    # against the impermanence bind mounts cannot shadow it (the same
    # workaround as jellyfin.nix); the upstream module adds its own rule for
    # the /var/lib path, which only chowns the bind target.
    systemd.tmpfiles.rules = [
      "d /per/var/lib/octoprint 0700 octoprint octoprint -"
    ];

    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/octoprint";
        user = "octoprint";
        group = "octoprint";
        mode = "0700";
      }
    ];
  };
}
