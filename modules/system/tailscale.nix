{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.tailscale;

  ntfySend = import ../../lib/ntfy-send.nix {inherit pkgs lib;};

  # Probes a peer and records reachability transitions in the journal, so an
  # outage can be timestamped after the fact (e.g. a phone that vanishes while
  # commuting). State lives in /run (tmpfs) because only transitions matter;
  # losing it on reboot at worst re-reports one down interval.
  #
  # A failed ping is classified against the control plane's own view of the
  # peer, because the two fail independently: an Android client can stay
  # Online for hours while its process is frozen and the VpnService stops
  # answering (observed 2026-10-13: 9318 s of unanswered pings with
  # Online=true). "wedged" therefore means the peer still has internet but its
  # tunnel data path is dead and the app has to be reopened; "offline" means
  # the control plane lost it too, so it has no internet or the client is not
  # running. The alert names which, so the recovery step is unambiguous.
  #
  # Delivery is not probed: the phone subscribes to the external topic
  # (alertNtfyPrimaryUrlFile), whose subscriber count this host's ntfy cannot
  # see, and no publish-side signal proves a push was rendered - only a
  # phone-side ack could, and there is none to read.
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

    # Routing: the external topic leads (primaryFile) because an alert about
    # the tailnet must not need the tailnet to leave this host; the local
    # topic is published to only when that fails, so one message normally
    # travels on exactly one channel.
    ${lib.optionalString (cfg.peerMonitor.alertNtfyPrimaryUrlFile != "" || cfg.peerMonitor.alertNtfyUrl != null) ''
      ${ntfySend {
        primaryFile = cfg.peerMonitor.alertNtfyPrimaryUrlFile;
        secondary =
          if cfg.peerMonitor.alertNtfyUrl == null
          then ""
          else cfg.peerMonitor.alertNtfyUrl;
      }}
      notify() {
        ntfy_send "Tailscale peer $1" "$2" "tailscale,warning" "$3"
      }
    ''}
    ${lib.optionalString (cfg.peerMonitor.alertNtfyPrimaryUrlFile == "" && cfg.peerMonitor.alertNtfyUrl == null) ''
      notify() { :; }
    ''}

    # The control plane's own view of the peer, read only when a ping failed,
    # to tell a frozen app from a peer that is genuinely gone (see the block
    # comment above). JSON, not the status table: the table truncates and its
    # columns are not a stable interface.
    classify() {
      "$tailscale" status --json 2>/dev/null | ${pkgs.jq}/bin/jq -r --arg p "$peer" '
        ([(.Peer // {})[] | select((.DNSName // "") | startswith($p + "."))] | first) as $v
        | if $v == null then "unknown"
          elif $v.Online then "wedged"
          else "offline" end' 2>/dev/null || echo unknown
    }

    # `tailscale ping` exits non-zero whenever no direct path is established,
    # even when every pong arrived over DERP - and a phone on cellular or
    # behind CGNAT is routinely DERP-only. The exit code therefore means "no
    # direct path", not "unreachable"; judge reachability by whether a pong
    # came back at all, and keep the ping only to report the path taken.
    out=$("$tailscale" ping --c=3 --timeout=5s "$peer" 2>&1) || true
    if printf '%s' "$out" | ${pkgs.gnugrep}/bin/grep -q 'pong from'; then
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
        case "$(classify)" in
          wedged)
            msg="peer $peer unreachable ($fail_count consecutive failed probes): the control plane still lists it Online, so it has internet but the app is frozen or its VpnService stopped. Open Tailscale on the phone to restore the tunnel."
            ;;
          offline)
            msg="peer $peer unreachable ($fail_count consecutive failed probes): the control plane lists it Offline too, so it has no internet or the client is not running."
            ;;
          *)
            msg="peer $peer unreachable ($fail_count consecutive failed probes); the control plane view could not be read."
            ;;
        esac
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
    relayServerPort = lib.mkOption {
      type = lib.types.nullOr lib.types.port;
      default = null;
      description = ''
        Port the relay server (DERP) this node runs for the tailnet binds to.
        null leaves it at the daemon default. Kept out of extraSetFlags unless
        set: the nixpkgs module only creates the tailscaled-set oneshot when
        extraSetFlags is non-empty, and a bare `tailscale set` there can fail
        while a node still awaits interactive login.
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
        default = 30;
        description = ''
          Seconds between connectivity probes. With failureThreshold=2 the
          default detects an outage inside a minute, which is the point: the
          phone's client drops for minutes to hours upstream, so the alert
          must not wait longer than the outage it reports.
        '';
      };
      failureThreshold = lib.mkOption {
        type = lib.types.ints.positive;
        default = 2;
        description = "Consecutive failed probes before the peer is reported unreachable.";
      };
      alertNtfyUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Local ntfy topic URL. Carries peer monitor alerts on its own while
          alertNtfyPrimaryUrlFile is empty, and becomes the fallback once
          that option leads; null drops the local channel, and with the
          out-of-band topic unset too, notifications are disabled entirely.
        '';
      };
      alertNtfyPrimaryUrlFile = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Path to a file containing the ntfy URL that receives peer monitor
          alerts first - an alert about the tailnet must not depend on the
          tailnet being up to leave this host, so the external topic is the
          primary channel here while maintenance alerts keep the local one
          as theirs. The same file backs
          maintenance.monitoring.secondaryNtfyUrlFile, which publishes to
          it only as a fallback for the reasons documented there. Keep the
          URL in a secret file: the topic name is password-equivalent.
          Empty makes the local topic (alertNtfyUrl) the only channel.
        '';
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
      # nodes without needing authKeyFile. The relay port rides the same
      # oneshot, and only when a host sets it.
      extraSetFlags =
        lib.optionals cfg.openSSH ["--ssh"]
        ++ lib.optionals (cfg.relayServerPort != null) ["--relay-server-port=${toString cfg.relayServerPort}"];
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
            # An expired node key fails the status check as well, but only an
            # interactive login clears it: restarting there just mints a new
            # auth URL under whoever is copying the current one, and the
            # tailscale-up that follows then blocks the unit until shutdown.
            state=$(${pkgs.tailscale}/bin/tailscale status --json 2>/dev/null \
              | ${pkgs.jq}/bin/jq -r '.BackendState // empty' 2>/dev/null)
            if [ "$state" = "NeedsLogin" ]; then
              echo "tailscale needs interactive login; not restarting tailscaled" >&2
            elif ! ${pkgs.tailscale}/bin/tailscale status >/dev/null 2>&1; then
              echo "tailscale status failed (state ''${state:-unknown}); restarting tailscaled" >&2
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
