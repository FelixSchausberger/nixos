{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.tailscale;

  # Probes a peer and records reachability transitions in the journal, so an
  # outage can be timestamped after the fact (e.g. a phone that vanishes while
  # commuting). State lives in /run (tmpfs) because only transitions matter;
  # losing it on reboot at worst re-reports one down interval.
  peerMonitorScript = pkgs.writeShellScript "tailscale-peer-monitor" ''
    set -eu

    state_dir=/run/tailscale-peer-monitor
    state_file="$state_dir/state"
    ${pkgs.coreutils}/bin/mkdir -p "$state_dir"

    peer=${lib.escapeShellArg cfg.peerMonitor.peer}
    threshold=${toString cfg.peerMonitor.failureThreshold}
    tailscale=${pkgs.tailscale}/bin/tailscale

    down_since=0
    fail_count=0
    if [ -f "$state_file" ]; then
      # shellcheck disable=SC1090
      . "$state_file" || true
    fi

    now=$(${pkgs.coreutils}/bin/date +%s)
    ts=$(${pkgs.coreutils}/bin/date -Is)

    ${lib.optionalString (cfg.peerMonitor.alertNtfyUrl != null) ''
      ntfy_url=${lib.escapeShellArg cfg.peerMonitor.alertNtfyUrl}
      notify() {
        ${pkgs.curl}/bin/curl -s -o /dev/null \
          -H "Title: Tailscale peer $1" \
          -H "Priority: $2" \
          -H "Tags: tailscale,warning" \
          -d "$3" "$ntfy_url" || true
      }
    ''}
    ${lib.optionalString (cfg.peerMonitor.alertNtfyUrl == null) ''
      notify() { :; }
    ''}

    if out=$("$tailscale" ping --c=3 --timeout=5s "$peer" 2>&1); then
      path=$(printf '%s' "$out" | ${pkgs.gnugrep}/bin/grep -oE 'via .* in [0-9.]+ms' || printf '%s' "$out")
      if [ "$down_since" -ne 0 ]; then
        duration=$(($now - down_since))
        msg="peer $peer recovered after ''${duration}s ($path)"
        echo "$ts $msg"
        notify "recovered" "default" "$msg"
        down_since=0
      else
        echo "$ts peer $peer reachable ($path)"
      fi
      fail_count=0
    else
      fail_count=$((fail_count + 1))
      if [ "$down_since" -eq 0 ] && [ "$fail_count" -ge "$threshold" ]; then
        down_since=$now
        msg="peer $peer unreachable ($fail_count consecutive failed probes)"
        echo "$ts $msg" >&2
        notify "unreachable" "urgent" "$msg"
      else
        echo "$ts peer $peer probe failed ($fail_count/$threshold)"
      fi
    fi

    printf 'down_since=%s\nfail_count=%s\n' "$down_since" "$fail_count" > "$state_file"
  '';
in {
  options.modules.system.homelab.tailscale = {
    enable = lib.mkEnableOption "Tailscale VPN";
    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to sops-decrypted Tailscale auth key for automated login";
    };
    advertiseRoutes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Subnet routes to advertise (e.g. [\"192.168.1.0/24\"])";
    };
    exitNode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Advertise this host as a Tailscale exit node";
    };
    acceptDns = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether Tailscale may manage DNS on this host (MagicDNS, split DNS,
        global nameservers). Disable on hosts whose connectivity must not
        depend on tailnet DNS resolvers (e.g. work machines).
      '';
    };
    openSSH = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Tailscale SSH: tailscaled intercepts port 22 from tailnet
        clients and authenticates by device identity (tailnet ACLs), while
        regular sshd keeps handling non-tailnet connections.
      '';
    };
    udpGROInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Network interface to apply UDP GRO forwarding fix for Tailscale throughput";
    };
    peerMonitor = {
      enable = lib.mkEnableOption "periodic tailnet peer connectivity monitor";
      peer = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "pixel-9a";
        description = "Tailnet peer (MagicDNS name or 100.x address) probed each interval.";
      };
      intervalSec = lib.mkOption {
        type = lib.types.ints.positive;
        default = 60;
        description = "Seconds between connectivity probes.";
      };
      failureThreshold = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2;
        description = "Consecutive failed probes before the peer is reported unreachable.";
      };
      alertNtfyUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional ntfy topic URL notified on reachability transitions.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.udpGROInterface == null || cfg.udpGROInterface != "";
        message = "modules.system.homelab.tailscale.udpGROInterface must be null or a non-empty interface name";
      }
      {
        assertion = !cfg.peerMonitor.enable || cfg.peerMonitor.peer != "";
        message = "modules.system.homelab.tailscale.peerMonitor.peer must be set when peerMonitor.enable is true";
      }
    ];

    services.tailscale = {
      enable = true;
      inherit (cfg) authKeyFile;
      openFirewall = true;
      # Pinned (not autoselected): the Fritz!Box holds a static UDP forward
      # for 41641 to this host, so the daemon port must not drift.
      port = 41641;
      # Tailscale SSH has no dedicated upstream option; `tailscale set --ssh`
      # (via the tailscaled-set oneshot) enables it for already-registered
      # nodes without needing authKeyFile.
      extraSetFlags = lib.optionals cfg.openSSH ["--ssh"];
      # Enables IP forwarding sysctls and correct rpfilter rules for subnet routing.
      # rpfilter fix prevents asymmetric routes from dropping subnet-routed packets.
      useRoutingFeatures = lib.mkIf (cfg.advertiseRoutes != [] || cfg.exitNode) "server";
      extraUpFlags =
        lib.optionals cfg.exitNode ["--advertise-exit-node"]
        ++ lib.optionals (cfg.advertiseRoutes != []) [
          "--advertise-routes=${lib.concatStringsSep "," cfg.advertiseRoutes}"
        ]
        ++ lib.optionals (!cfg.acceptDns) ["--accept-dns=false"];
    };

    # Improves UDP forwarding throughput for Tailscale when interface is specified
    systemd = {
      services."tailscale-udp-gro-fix" = lib.mkIf (cfg.udpGROInterface != null) {
        description = "Apply UDP GRO forwarding settings for Tailscale on ${cfg.udpGROInterface}";
        after = ["network.target"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.ethtool}/bin/ethtool -K ${cfg.udpGROInterface} rx-udp-gro-forwarding on rx-gro-list off";
        };
      };

      # Self-healing watchdog: if tailscaled is up but has not authenticated /
      # joined the tailnet, restart the service to re-establish connectivity.
      # Protects against a single transient failure (stale state, brief network
      # outage at boot) stranding the host unreachable via Tailscale.
      timers.tailscale-watchdog = {
        description = "Ensure Tailscale stays connected";
        wantedBy = ["timers.target"];
        after = ["tailscaled.service"];
        timerConfig = {
          OnBootSec = "5min";
          OnUnitActiveSec = "10min";
          RandomizedDelaySec = "30s";
        };
      };

      services.tailscale-watchdog = {
        description = "Restart tailscaled if the tailnet link is down";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.writeShellScript "tailscale-watchdog" ''
            if ! ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
              echo "tailscale status failed; restarting tailscaled" >&2
              ${pkgs.systemd}/bin/systemctl restart tailscaled
              sleep 15
              # Re-establish the tailnet from the daemon's persisted config
              # (routes/DNS/exit-node are held by tailscaled, not the CLI).
              ${pkgs.tailscale}/bin/tailscale up || echo "tailscale reconnection failed" >&2
            fi
          ''}";
        };
      };

      # Peer reachability probe: records every transition in the journal so a
      # later outage can be dated without relying on the user's memory. Kept
      # separate from the watchdog, which only acts on the local daemon.
      services.tailscale-peer-monitor = lib.mkIf cfg.peerMonitor.enable {
        description = "Probe tailnet peer ${cfg.peerMonitor.peer} and log reachability transitions";
        after = ["tailscaled.service"];
        wants = ["tailscaled.service"];
        serviceConfig = {
          Type = "oneshot";
          RuntimeDirectory = "tailscale-peer-monitor";
          RuntimeDirectoryPreserve = "yes";
          ExecStart = "${peerMonitorScript}";
        };
      };

      timers.tailscale-peer-monitor = lib.mkIf cfg.peerMonitor.enable {
        description = "Periodic tailnet peer connectivity probe";
        wantedBy = ["timers.target"];
        after = ["tailscaled.service"];
        timerConfig = {
          OnBootSec = "2min";
          OnUnitActiveSec = "${toString cfg.peerMonitor.intervalSec}s";
          RandomizedDelaySec = "10s";
        };
      };
    };

    # Allow all traffic on the Tailscale interface
    networking.firewall.trustedInterfaces = ["tailscale0"];

    environment.persistence."/per".directories = [
      {
        directory = "/var/lib/tailscale";
        user = "root";
        group = "root";
        mode = "0750";
      }
    ];
  };
}
