{
  config,
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
    BROADCAST_IP = "${cfg.broadcastIp}"
    WOL_PORT = ${toString cfg.wolPort}
    LISTEN_PORT = ${toString cfg.port}


    def desktop_online():
        try:
            s = socket.create_connection(
                (DESKTOP_IP, DESKTOP_CHECK_PORT), timeout=2
            )
            s.close()
            return True
        except (socket.timeout, ConnectionRefusedError, OSError):
            return False


    def wake_desktop():
        magic = b"\xff" * 6 + DESKTOP_MAC * 16
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.sendto(magic, (BROADCAST_IP, WOL_PORT))
        sock.close()


    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/api/status":
                self._send_json(
                    {
                        "desktop": (
                            "online" if desktop_online() else "offline"
                        )
                    }
                )
            elif self.path == "/":
                self._send_html(HTML)
            else:
                self.send_error(404)

        def do_POST(self):
            if self.path == "/api/wake":
                threading.Thread(target=wake_desktop, daemon=True).start()
                self._send_json({"status": "waking"})
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
      .status{display:flex;align-items:center;gap:0.75rem;justify-content:center;margin-bottom:2rem;padding:0.75rem;border-radius:0.5rem;background:#0f3460}
      .dot{width:0.75rem;height:0.75rem;border-radius:50%;flex-shrink:0}
      .dot.online{background:#4ecca3;box-shadow:0 0 8px #4ecca3}
      .dot.offline{background:#e94560;box-shadow:0 0 8px #e94560}
      .dot.waking{background:#ffd369;box-shadow:0 0 8px #ffd369;animation:pulse 0.6s ease-in-out infinite}
      @keyframes pulse{50%{opacity:0.3}}
      button{width:100%;padding:1rem;border:none;border-radius:0.5rem;font-size:1rem;font-weight:600;cursor:pointer;background:#e94560;color:#fff;transition:background 0.15s;margin-bottom:0.75rem}
      button:hover{background:#d63851}
      button:disabled{opacity:0.4;cursor:not-allowed}
      button.secondary{background:#0f3460}
      button.secondary:hover{background:#1a4a8a}
      .error{color:#e94560;text-align:center;margin-top:0.75rem;display:none;font-size:0.875rem}
    </style>
    </head>
    <body>
    <div class="card">
      <h1>Remote Control</h1>
      <p class="subtitle">schausberger @ desktop</p>
      <div class="status" id="status">
        <span class="dot offline" id="dot"></span>
        <span id="label">Checking...</span>
      </div>
      <button id="wakeBtn" onclick="wake()">Wake Desktop</button>
      <button class="secondary" onclick="window.location.href='https://steamcommunity.com/id/schausberger'" target="_blank">Open Steam</button>
      <div class="error" id="error"></div>
    </div>
    <script>
      async function refresh() {
        try {
          const r = await fetch("/api/status");
          const d = await r.json();
          const dot = document.getElementById("dot");
          const label = document.getElementById("label");
          dot.className = "dot " + d.desktop;
          label.textContent = d.desktop === "online" ? "Desktop is online" : "Desktop is offline";
          document.getElementById("wakeBtn").disabled = d.desktop === "online";
        } catch(e) {
          document.getElementById("label").textContent = "Connection error";
        }
      }
      async function wake() {
        document.getElementById("wakeBtn").disabled = true;
        document.getElementById("dot").className = "dot waking";
        document.getElementById("label").textContent = "Waking desktop...";
        document.getElementById("error").style.display = "none";
        try {
          await fetch("/api/wake", { method: "POST" });
          [3, 6, 9, 12, 15, 20, 30].forEach(s => setTimeout(refresh, s * 1000));
        } catch(e) {
          document.getElementById("error").textContent = "Failed to send wake signal";
          document.getElementById("error").style.display = "block";
          document.getElementById("wakeBtn").disabled = false;
        }
      }
      refresh();
      setInterval(refresh, 15000);
    </script>
    </body>
    </html>"""


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
      default = "192.168.178.3";
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
