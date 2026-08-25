{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.remoteControl;

  desktopMac = lib.toUpper (builtins.replaceStrings [":"] [""] cfg.desktopMac);

  webServer = pkgs.writeText "remote-control.py" ''
    import http.server
    import json
    import socket
    import threading

    DESKTOP_IP = "${cfg.desktopIp}"
    DESKTOP_MAC = bytes.fromhex("${desktopMac}")
    DESKTOP_CHECK_PORT = ${toString cfg.desktopCheckPort}
    SUNSHINE_PORT = ${toString cfg.sunshinePort}
    STEAM_PORT = ${toString cfg.steamRemotePlayPort}
    BROADCAST_IP = "${cfg.broadcastIp}"
    WOL_PORT = ${toString cfg.wolPort}
    LISTEN_PORT = ${toString cfg.port}


    def check_port(host, port, timeout=2):
        try:
            s = socket.create_connection((host, port), timeout=timeout)
            s.close()
            return True
        except (socket.timeout, ConnectionRefusedError, OSError):
            return False


    def desktop_online():
        return check_port(DESKTOP_IP, DESKTOP_CHECK_PORT)


    def wake_desktop():
        magic = b"\xff" * 6 + DESKTOP_MAC * 16
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(magic, (BROADCAST_IP, WOL_PORT))
        sock.close()


    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/api/status":
                online = desktop_online()
                sunshine = check_port(DESKTOP_IP, SUNSHINE_PORT) if online else False
                steam = check_port(DESKTOP_IP, STEAM_PORT) if online else False
                self._send_json({
                    "desktop": "online" if online else "offline",
                    "sunshine": "running" if sunshine else "stopped",
                    "steam": "running" if steam else "stopped",
                })
            elif self.path == "/":
                self._send_html(HTML)
            else:
                self.send_error(404)

        def do_POST(self):
            if self.path == "/api/wake":
                threading.Thread(target=wake_desktop, daemon=True).start()
                self._send_json({"status": "waking"})
            elif self.path == "/api/toggle":
                online = desktop_online()
                if not online:
                    threading.Thread(target=wake_desktop, daemon=True).start()
                    self._send_json({"action": "wake", "ok": True})
                else:
                    self._send_json({"action": "none", "ok": False})
            else:
                self.send_error(404)

        def _send_json(self, data):
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(json.dumps(data).encode())

        def _send_html(self, html):
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(html.encode())

        def log_message(self, fmt, *args):
            pass


    HTML = """<!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Remote Control</title>
    <style>
      *{box-sizing:border-box;margin:0;padding:0}
      body{font-family:system-ui,-apple-system,sans-serif;background:#1a1a2e;color:#eee;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:1rem}
      .card{background:#16213e;border-radius:1rem;padding:2rem;width:100%;max-width:24rem;box-shadow:0 8px 32px rgba(0,0,0,0.3)}
      h1{text-align:center;font-size:1.5rem;margin-bottom:0.5rem;color:#e94560}
      .subtitle{text-align:center;font-size:0.875rem;color:#889;margin-bottom:1.5rem}
      .status-group{margin-bottom:1.5rem;padding:0.75rem;border-radius:0.5rem;background:#0f3460}
      .status-row{display:flex;align-items:center;gap:0.75rem;padding:0.35rem 0}
      .status-row+.status-row{border-top:1px solid rgba(255,255,255,0.08)}
      .dot{width:0.75rem;height:0.75rem;border-radius:50%;flex-shrink:0}
      .dot.online{background:#4ecca3;box-shadow:0 0 8px #4ecca3}
      .dot.offline{background:#e94560;box-shadow:0 0 8px #e94560}
      .dot.stopped{background:#e94560;box-shadow:0 0 8px #e94560}
      .dot.running{background:#4ecca3;box-shadow:0 0 8px #4ecca3}
      .dot.unknown{background:#555;box-shadow:0 0 4px #555}
      .dot.waking{background:#ffd369;box-shadow:0 0 8px #ffd369;animation:pulse 0.6s ease-in-out infinite}
      @keyframes pulse{50%{opacity:0.3}}
      .status-label{font-size:0.875rem;color:#ccc}
      .status-label strong{color:#eee}
      button{width:100%;padding:1rem;border:none;border-radius:0.5rem;font-size:1rem;font-weight:600;cursor:pointer;color:#fff;transition:background 0.15s;margin-bottom:0.75rem}
      button:hover{filter:brightness(0.9)}
      button:disabled{opacity:0.4;cursor:not-allowed;filter:none}
      .btn-wake{background:#e94560}
      .error{color:#e94560;text-align:center;margin-top:0.75rem;display:none;font-size:0.875rem}
    </style>
    </head>
    <body>
    <div class="card">
      <h1>Remote Control</h1>
      <p class="subtitle">schausberger @ desktop</p>
      <div class="status-group" id="statusGroup">
        <div class="status-row">
          <span class="dot unknown" id="dotDesktop"></span>
          <span class="status-label" id="labelDesktop">Desktop: checking...</span>
        </div>
        <div class="status-row">
          <span class="dot unknown" id="dotMoonshine"></span>
          <span class="status-label" id="labelMoonshine">Moonshine: --</span>
        </div>
        <div class="status-row">
          <span class="dot unknown" id="dotSteam"></span>
          <span class="status-label" id="labelSteam">Steam: --</span>
        </div>
      </div>
      <button id="actionBtn" class="btn-wake" onclick="toggle()">--</button>
      <div class="error" id="error"></div>
    </div>
    <script>
      let currentState = {};
      async function refresh() {
        try {
          const r = await fetch("/api/status");
          const d = await r.json();
          currentState = d;
          const online = d.desktop === "online";
          document.getElementById("dotDesktop").className = "dot " + d.desktop;
          document.getElementById("labelDesktop").innerHTML = "<strong>Desktop</strong> " + (online ? "online" : "offline");
          document.getElementById("dotMoonshine").className = "dot " + (online ? d.sunshine : "unknown");
          document.getElementById("labelMoonshine").innerHTML = "<strong>Moonshine</strong> " + (online ? d.sunshine : "--");
          document.getElementById("dotSteam").className = "dot " + (online ? d.steam : "unknown");
          document.getElementById("labelSteam").innerHTML = "<strong>Steam</strong> " + (online ? d.steam : "--");
          const btn = document.getElementById("actionBtn");
          if (!online) {
            btn.textContent = "Wake Desktop";
            btn.className = "btn-wake";
            btn.disabled = false;
          } else {
            btn.textContent = "Desktop Online";
            btn.className = "btn-wake";
            btn.disabled = true;
          }
        } catch(e) {
          document.getElementById("labelDesktop").innerHTML = "<strong>Desktop</strong> connection error";
        }
      }
      async function toggle() {
        const btn = document.getElementById("actionBtn");
        btn.disabled = true;
        document.getElementById("error").style.display = "none";
        const wasOffline = currentState.desktop !== "online";
        if (wasOffline) {
          document.getElementById("dotDesktop").className = "dot waking";
          document.getElementById("labelDesktop").innerHTML = "<strong>Desktop</strong> waking...";
        }
        try {
          await fetch("/api/toggle", { method: "POST" });
          const delays = wasOffline ? [3, 6, 9, 12, 15, 20, 30] : [1, 3, 5];
          delays.forEach(s => setTimeout(refresh, s * 1000));
        } catch(e) {
          document.getElementById("error").textContent = "Action failed";
          document.getElementById("error").style.display = "block";
          btn.disabled = false;
        }
      }
      refresh();
      setInterval(refresh, 15000);
    </script>
    </body>
    </html>""";


    if __name__ == "__main__":
        http.server.HTTPServer(
            ("0.0.0.0", LISTEN_PORT), Handler
        ).serve_forever()
  '';
in {
  options.modules.system.homelab.remoteControl = {
    enable = lib.mkEnableOption "Web-based remote control for homelab devices";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Port for the remote control web interface";
    };

    desktopIp = lib.mkOption {
      type = lib.types.str;
      default = inputs.self.lib.hosts.desktop.ip or "192.168.178.3";
      description = "IP address of the desktop to control";
    };

    desktopMac = lib.mkOption {
      type = lib.types.str;
      default = "10:ff:e0:e1:53:55";
      description = "MAC address of the desktop for Wake-on-LAN";
    };

    desktopCheckPort = lib.mkOption {
      type = lib.types.port;
      default = 22;
      description = "TCP port to probe when checking if desktop is online";
    };

    sunshinePort = lib.mkOption {
      type = lib.types.port;
      default = 47989;
      description = "Moonshine HTTP port on the desktop for status checks";
    };

    steamRemotePlayPort = lib.mkOption {
      type = lib.types.port;
      default = 27036;
      description = "Steam Remote Play port on the desktop for status checks";
    };

    broadcastIp = lib.mkOption {
      type = lib.types.str;
      default = "192.168.178.255";
      description = "Broadcast IP for the local subnet (Wake-on-LAN target)";
    };

    wolPort = lib.mkOption {
      type = lib.types.port;
      default = 9;
      description = "UDP port for Wake-on-LAN magic packets";
    };

    enableTailscaleServe = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Expose the remote control web UI via Tailscale Serve for a memorable HTTPS URL";
    };

    tailscaleServeHttpsPort = lib.mkOption {
      type = lib.types.port;
      default = 443;
      description = "HTTPS port for Tailscale Serve";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.remote-control = {
      description = "Web-based remote control for homelab";
      after = [
        "network.target"
        "tailscale.service"
      ];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${webServer}";
        Restart = "always";
        RestartSec = "5";
        # Stateless status prober + WoL sender: runs as an unprivileged
        # dynamic user (no SSH keys or home access needed).
        DynamicUser = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        CapabilityBoundingSet = [
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_BROADCAST"
        ];
        AmbientCapabilities = [
          "CAP_NET_BIND_SERVICE"
          "CAP_NET_BROADCAST"
        ];
      };
    };

    networking.firewall.allowedTCPPorts = [cfg.port];

    systemd.services.tailscale-serve-remote-control = lib.mkIf cfg.enableTailscaleServe {
      description = "Expose remote-control web UI via Tailscale Serve";
      after = [
        "tailscale.service"
        "remote-control.service"
      ];
      wants = [
        "tailscale.service"
        "remote-control.service"
      ];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = 30;
        ExecStart = "${pkgs.writeShellScript "tailscale-serve-setup" ''
          ${pkgs.tailscale}/bin/tailscale serve --bg \
            --https ${toString cfg.tailscaleServeHttpsPort} \
            http://127.0.0.1:${toString cfg.port} \
            || echo "Warning: tailscale serve setup failed (non-fatal)"
        ''}";
      };
    };
  };
}
