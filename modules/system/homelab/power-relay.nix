# LAN power relay for the desktop workstation.
# Magic packets are L2 broadcast frames and cannot traverse Tailscale's
# point-to-point L3 overlay (tailscale/tailscale#306), so remote wake
# requests arrive here over the tailnet and are replayed as LAN broadcast.
# The service observes the outcome of each action (ping poll) and reports
# the real result to ntfy, since a magic packet itself is fire-and-forget.
# Phone setup: HTTP shortcut posting to http://<bindAddress>:<port>/wake
# or /shutdown, optionally with an ?token=<token> query parameter when
# configured. GET /status answers {"up": <bool>} for instant state checks.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.powerRelay;
in {
  options.modules.system.homelab.powerRelay = {
    enable = lib.mkEnableOption "LAN power relay for remote desktop wake and shutdown";

    bindAddress = lib.mkOption {
      type = lib.types.str;
      description = "Address to bind on, typically the host's Tailscale address, keeping the relay off the LAN";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8691;
      description = "TCP port the relay listens on";
    };

    macAddress = lib.mkOption {
      type = lib.types.str;
      description = "MAC address for the wake magic packet";
    };

    broadcastAddress = lib.mkOption {
      type = lib.types.str;
      description = "Directed broadcast address to send the wake packet to";
    };

    hostAddress = lib.mkOption {
      type = lib.types.str;
      description = "Target IP for the reachability polls that verify wake and shutdown outcomes";
    };

    sshHost = lib.mkOption {
      type = lib.types.str;
      description = "SSH destination for the graceful shutdown command";
    };

    token = lib.mkOption {
      type = lib.types.nullOr lib.types.nonEmptyStr;
      default = null;
      description = "Shared secret required on mutating requests; null means the Tailscale-only binding is the auth boundary";
    };

    ntfyUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:2586";
      description = "Local ntfy endpoint used for outcome notifications";
    };

    ntfyTopic = lib.mkOption {
      type = lib.types.str;
      default = "desktop-power";
      description = "ntfy topic the wake/shutdown outcomes are published to";
    };

    wakeTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 240;
      description = "Wake poll window in seconds";
    };

    shutdownTimeout = lib.mkOption {
      type = lib.types.ints.positive;
      default = 90;
      description = "Shutdown poll window in seconds";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.power-relay = {
      description = "LAN power relay: remote desktop wake, shutdown and status checks";
      wantedBy = ["multi-user.target"];
      after = ["network-online.target" "tailscaled.service" "ntfy-sh.service"];
      wants = ["network-online.target"];

      path = with pkgs; [
        iputils # ping as loaded setuid wrapper, with CAP_NET_RAW
        wakeonlan
        openssh
      ];

      serviceConfig = {
        ExecStart = let
          script = pkgs.writers.writePython3 "power-relay" {flakeIgnore = ["E501"];} ''
            import argparse
            import json
            import subprocess
            import sys
            import threading
            import time
            import urllib.parse
            import urllib.request
            from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

            AP = argparse.ArgumentParser(description="LAN power relay")
            AP.add_argument("--bind", required=True)
            AP.add_argument("--port", type=int, required=True)
            AP.add_argument("--mac", required=True)
            AP.add_argument("--broadcast", required=True)
            AP.add_argument("--host", required=True)
            AP.add_argument("--ssh-host", required=True)
            AP.add_argument("--token", default=None)
            AP.add_argument("--ntfy-url", default=None)
            AP.add_argument("--ntfy-topic", default="desktop-power")
            AP.add_argument("--wake-timeout", type=int, default=240)
            AP.add_argument("--shutdown-timeout", type=int, default=90)
            ARGS = AP.parse_args()


            def reachable():
                """ICMP probe; the desktop answers ping ~1s after power-on."""
                r = subprocess.run(
                    ["ping", "-c", "1", "-W", "1", ARGS.host],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                )
                return r.returncode == 0


            def notify(title, message, priority="default", tags="bell"):
                if ARGS.ntfyUrl is None:
                    return
                try:
                    req = urllib.request.Request(
                        f"{ARGS.ntfyUrl}/{ARGS.ntfyTopic}",
                        data=message.encode(),
                        headers={"Title": title, "Priority": priority, "Tags": tags},
                    )
                    urllib.request.urlopen(req, timeout=5).close()
                except OSError as err:
                    print(f"ntfy publish failed: {err}", file=sys.stderr)


            def record_wake():
                deadline = time.monotonic() + ARGS.wakeTimeout
                while time.monotonic() < deadline:
                    if reachable():
                        notify(
                            "Desktop is up",
                            "desktop is awake (wake succeeded)",
                            "low", "electric_plug",
                        )
                        return
                    time.sleep(5)
                notify(
                    "Desktop did not wake",
                    f"magic packet sent, host still unreachable after {ARGS.wakeTimeout}s",
                    "high", "warning",
                )


            def record_shutdown():
                deadline = time.monotonic() + ARGS.shutdownTimeout
                while time.monotonic() < deadline:
                    if not reachable():
                        notify(
                            "Desktop is off",
                            f"desktop powered down (within {ARGS.shutdownTimeout}s)",
                            "low", "moon",
                        )
                        return
                    time.sleep(3)
                notify(
                    "Desktop still on",
                    "poweroff was accepted but the host stayed reachable",
                    "high", "warning",
                )


            def authorized(path):
                if ARGS.token is None:
                    return True
                return urllib.parse.parse_qs(urllib.parse.urlparse(path).query).get(
                    "token", [None]
                ) == [ARGS.token]


            class Relay(BaseHTTPRequestHandler):
                def log_message(self, fmt, *args):
                    """One journald-visible line per request (method, path, status)."""
                    sys.stderr.write(f"{self.client_address[0]} {fmt % args}\n")

                def respond(self, code, payload):
                    body = json.dumps(payload).encode()
                    self.send_response(code)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)

                def do_GET(self):
                    if urllib.parse.urlparse(self.path).path == "/status":
                        self.respond(200, {"up": reachable()})
                    else:
                        self.respond(404, {"error": "not found"})

                def do_POST(self):
                    if not authorized(self.path):
                        self.respond(401, {"error": "invalid token"})
                        return
                    route = urllib.parse.urlparse(self.path).path
                    if route == "/wake":
                        if reachable():
                            self.respond(200, {"up": True, "queued": False})
                            return
                        subprocess.run(
                            ["wakeonlan", "-i", ARGS.broadcast, ARGS.mac],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                            check=False,
                        )
                        threading.Thread(target=record_wake, daemon=True).start()
                        self.respond(202, {"up": False, "queued": True})
                    elif route == "/shutdown":
                        if not reachable():
                            self.respond(200, {"up": False, "queued": False})
                            return
                        r = subprocess.run(
                            [
                                "ssh",
                                "-o",
                                "BatchMode=yes",
                                "-o",
                                "ConnectTimeout=5",
                                ARGS.sshHost,
                                "sudo",
                                "-n",
                                "/run/current-system/sw/bin/poweroff",
                            ],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.PIPE,
                            check=False,
                        )
                        if r.returncode != 0:
                            print(
                                f"ssh poweroff failed: "
                                f"exit {r.returncode}: {r.stderr.decode()!r}",
                                file=sys.stderr,
                            )
                            self.respond(502, {"error": "ssh poweroff command failed"})
                            notify(
                                "Desktop shutdown failed",
                                "could not run poweroff over SSH",
                                "high", "warning",
                            )
                            return
                        threading.Thread(target=record_shutdown, daemon=True).start()
                        self.respond(202, {"up": True, "queued": True})
                    else:
                        self.respond(404, {"error": "not found"})


            ThreadingHTTPServer.daemon_threads = True
            ThreadingHTTPServer((ARGS.bind, ARGS.port), Relay).serve_forever()
          '';
          args =
            [
              "--bind ${cfg.bindAddress}"
              "--port ${toString cfg.port}"
              "--mac ${cfg.macAddress}"
              "--broadcast ${cfg.broadcastAddress}"
              "--host ${cfg.hostAddress}"
              "--ssh-host ${cfg.sshHost}"
              "--ntfy-url ${cfg.ntfyUrl}"
              "--ntfy-topic ${cfg.ntfyTopic}"
              "--wake-timeout ${toString cfg.wakeTimeout}"
              "--shutdown-timeout ${toString cfg.shutdownTimeout}"
            ]
            ++ lib.optionals (cfg.token != null) ["--token ${cfg.token}"];
        in
          lib.concatStringsSep " " (["${script}/bin/power-relay"] ++ args);
        DynamicUser = true;
        PrivateTmp = true;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    # No firewall entry: the service binds to the Tailscale address only, so
    # opening it on eno1's firewall ruleset would be reachable before the
    # bind fails on the LAN address. Tailscale ACLs govern tailnet access.
  };
}
