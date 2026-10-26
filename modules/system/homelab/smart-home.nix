# Zigbee smart home stack: SMLIGHT SLZB-MR4U LAN coordinator, MQTT broker,
# Zigbee2MQTT and Home Assistant.
#
# Architecture:
#   - The coordinator is reached over the network, not USB: SLZB-OS serves each
#     radio of the MR4U on a TCP port (the MR manual lists 6638/7638 as the
#     per-slot defaults; the device dashboard shows the exact values). Radio 1
#     (CC2674P10) runs the Zigbee 3.0 coordinator firmware; radio 2
#     (EFR32MG26) stays spare for a later Matter-over-Thread border router
#     (services.openthread-border-router + services.matter-server), so the
#     bulbs keep their full Zigbee feature set either way.
#   - Mosquitto binds loopback only and authenticates nobody: its only clients
#     live on this host. The trust level matches the unauthenticated Homepage
#     dashboard behind Tailscale Serve. If a broker client ever appears on the
#     LAN (e.g. ESPHome devices), add listener users with sops passwordFiles
#     and a LAN listener here.
#   - Home Assistant and the Zigbee2MQTT frontend are root-served single-page
#     UIs, so both get dedicated Tailscale Serve ports instead of a Caddy path
#     prefix (same pattern as zellij-web and the Prometheus UI).
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.smartHome;
  hl = config.modules.system.homelab;

  tailscaleServe = import ../../../lib/tailscale-serve.nix {inherit pkgs;};

  # Ports already claimed by other Tailscale Serve frontends on this host; the
  # two slots below must stay outside it.
  servePorts = [
    hl.zellijWeb.httpsPort
    hl.opencodeWeb.httpsPort
    hl.homepage.httpsPort
    hl.monitoring.prometheusHttpsPort
    hl.vaultwarden.httpsPort
  ];
in {
  options.modules.system.homelab.smartHome = {
    enable = lib.mkEnableOption "MQTT broker, Zigbee2MQTT and Home Assistant";

    coordinatorUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      # Null until the SLZB-MR4U sits on the LAN with a reserved address: a
      # network-dead coordinator would leave zigbee2mqtt restart-looping on
      # this always-on host, which comin auto-deploys to main. The serial
      # address is a plain LAN endpoint, not a secret.
      default = null;
      example = "tcp://192.168.178.20:6638";
      description = ''
        Zigbee coordinator serial URL. This is the SLZB-OS endpoint of the
        radio running the Zigbee coordinator firmware (radio 1 on the MR4U).
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = inputs.self.lib.homelabPorts.homeAssistant;
      description = "Home Assistant loopback HTTP port";
    };

    httpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8448;
      description = "Tailscale Serve HTTPS port for the Home Assistant UI";
    };

    frontendPort = lib.mkOption {
      type = lib.types.port;
      default = inputs.self.lib.homelabPorts.zigbee2mqtt;
      description = "Zigbee2MQTT frontend loopback port";
    };

    frontendHttpsPort = lib.mkOption {
      type = lib.types.port;
      default = 8449;
      description = "Tailscale Serve HTTPS port for the Zigbee2MQTT frontend";
    };

    lanClients = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["192.168.178.72"];
      description = ''
        LAN addresses that may reach Home Assistant directly on the home
        network (plain HTTP, password-gated by HA). When non-empty, HA binds
        the m920q LAN address beside loopback and one accept rule per client
        is generated; the tailnet Serve front is unaffected.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          (!builtins.elem cfg.httpsPort servePorts) && (!builtins.elem cfg.frontendHttpsPort servePorts) && cfg.httpsPort != cfg.frontendHttpsPort;
        message = "modules.system.homelab.smartHome httpsPort/frontendHttpsPort must differ from the zellij-web, opencode-web, homepage, Prometheus and vaultwarden Tailscale Serve ports and from each other";
      }
    ];

    # --- MQTT broker: loopback clients only, no authentication needed
    services = {
      mosquitto = {
        enable = true;
        # The NixOS module always installs the acl_file plugin, and an empty
        # ACL file is default-deny; pattern readwrite opens every topic so the
        # two local clients can publish and subscribe.
        listeners = [
          {
            address = "127.0.0.1";
            omitPasswordAuth = true;
            # per_listener_settings is on (the module emits it), and mosquitto
            # 2.x refuses anonymous clients unless allow_anonymous is set.
            settings.allow_anonymous = true;
            acl = ["pattern readwrite #"];
          }
        ];
      };

      # --- Zigbee2MQTT: starts once the coordinator exists on the network
      zigbee2mqtt = lib.mkIf (cfg.coordinatorUrl != null) {
        enable = true;
        settings = {
          permit_join = false;
          # Devices that stop reporting show as "unavailable" in Home
          # Assistant after the availability timeout instead of keeping a
          # stale state.
          availability = {
            enabled = true;
          };
          # Frontend and logs show when a device last reported; the primary
          # tool when a bulb starts misbehaving.
          advanced.last_seen = "ISO_8601";
          # The MR4U exposes its radios by chip family: 6638 is the EFR32MG26
          # (EmberZNet 8.0.2) and 7638 the TI CC2674P10. The Ember radio carries
          # the Zigbee network here, leaving the TI radio free for the later
          # Thread/Matter path. SLZB-OS serves that serial port over TCP at the
          # stick's reserved address; the adapter name lives under serial.
          serial = {
            port = cfg.coordinatorUrl;
            adapter = "ember";
          };
          frontend = {
            enabled = true;
            host = "127.0.0.1";
            port = cfg.frontendPort;
          };
          # Channel 25 keeps the mesh clear of the Fritz!Box WiFi band. A
          # channel change rebuilds the coordinator network, so this is an
          # initial-network decision, not a later tweak.
          advanced.channel = 25;
        };
      };

      # --- Home Assistant: publishes the MQTT discovery data Zigbee2MQTT emits
      home-assistant = {
        enable = true;
        # Both components below are compiled into the HA python env; shelly is
        # listed because the LAN Shelly plugs trigger discovery requests, and
        # a missing module turns those into an error loop.
        extraComponents = ["mqtt" "shelly"];
        config = {
          default_config = {};
          http = {
            # Loopback always (the Tailscale Serve front), plus the m920q LAN
            # address when direct home-network clients are configured.
            server_host =
              ["127.0.0.1"]
              ++ lib.optional (cfg.lanClients != []) inputs.self.lib.hosts.m920q.ip;
            server_port = cfg.port;
            # The Tailscale Serve front terminates TLS and reaches HA from
            # 127.0.0.1; trusting it keeps client IPs and secure cookies intact.
            use_x_forwarded_for = true;
            trusted_proxies = ["127.0.0.1"];
          };
          # No mqtt section: HA 2026.10 removed the mqtt YAML import, and any
          # leftover keys fail integration setup, which retrains the HTTP
          # config trial and re-binds the API to the default addresses.
          # The MQTT integration is added once in the UI (broker
          # 127.0.0.1:1883, the local mosquitto above, no credentials).
        };
      };
    };

    # Home Assistant RSS alone is in the gigabyte range; cap it so a runaway
    # integration cannot evict immich/jellyfin on the 16 GB host (same
    # protection pattern as jellyfin.nix). Z2M would hang on a dead broker, so
    # it must start after mosquitto.
    #
    # Tailscale Serve fronts. Root-served UIs cannot ride a path-stripped
    # Caddy route, so each gets its own Serve port on the node certificate.
    systemd.services = {
      home-assistant.serviceConfig = {
        MemoryMax = "1500M";
        MemoryHigh = "1200M";
      };

      zigbee2mqtt = lib.mkIf (cfg.coordinatorUrl != null) {
        after = ["mosquitto.service"];
        wants = ["mosquitto.service"];
      };

      tailscale-serve-home-assistant = lib.mkIf hl.caddyProxy.enable (
        tailscaleServe {
          name = "tailscale-serve-home-assistant";
          description = "Expose Home Assistant via Tailscale Serve";
          inherit (cfg) httpsPort;
          upstreamPort = cfg.port;
          after = ["home-assistant.service"];
          wants = ["home-assistant.service"];
        }
      );

      tailscale-serve-zigbee2mqtt = lib.mkIf (hl.caddyProxy.enable && cfg.coordinatorUrl != null) (
        tailscaleServe {
          name = "tailscale-serve-zigbee2mqtt";
          description = "Expose the Zigbee2MQTT frontend via Tailscale Serve";
          httpsPort = cfg.frontendHttpsPort;
          upstreamPort = cfg.frontendPort;
          after = ["zigbee2mqtt.service"];
          wants = ["zigbee2mqtt.service"];
        }
      );
    };

    # Direct home-network clients (plain HTTP; HA's own login gates them). One
    # accept rule per client keeps the generated nftables free of set-literal
    # syntax (the same pattern as the Loki clientSources rules).
    networking.firewall.extraInputRules = lib.mkIf (cfg.lanClients != []) (
      lib.concatMapStringsSep "\n"
      (client: "ip saddr ${client} tcp dport ${toString cfg.port} accept")
      cfg.lanClients
    );

    # State directories survive reboots on the impermanence host. The tmpfiles
    # rules create them under the mount source directly so the ordering
    # against the impermanence bind mounts cannot shadow them (the same
    # workaround as jellyfin.nix).
    #
    # Home Assistant migrates the http section of configuration.yaml into
    # /var/lib/hass/.storage/http on first boot and ignores the YAML afterwards
    # (its fallback logic rebinds the API to the default addresses whenever an
    # integration section fails validation). Future http option changes
    # therefore require moving that store file aside before restarting.
    systemd.tmpfiles.rules =
      [
        "d /per/var/lib/hass 0700 hass hass -"
        "d /per/var/lib/mosquitto 0700 mosquitto mosquitto -"
      ]
      ++ lib.optionals (cfg.coordinatorUrl != null) [
        "d /per/var/lib/zigbee2mqtt 0700 zigbee2mqtt zigbee2mqtt -"
      ];

    environment.persistence."/per".directories =
      [
        {
          directory = "/var/lib/hass";
          user = "hass";
          group = "hass";
          mode = "0700";
        }
        {
          directory = "/var/lib/mosquitto";
          user = "mosquitto";
          group = "mosquitto";
          mode = "0700";
        }
      ]
      ++ lib.optionals (cfg.coordinatorUrl != null) [
        {
          directory = "/var/lib/zigbee2mqtt";
          user = "zigbee2mqtt";
          group = "zigbee2mqtt";
          mode = "0700";
        }
      ];
  };
}
