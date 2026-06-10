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
    import subprocess
    import threading

    DESKTOP_IP = "${cfg.desktopIp}"
    DESKTOP_USER = "${cfg.desktopUser}"
    DESKTOP_MAC = bytes.fromhex("${desktopMac}")
    DESKTOP_CHECK_PORT = ${toString cfg.desktopCheckPort}
    SUNSHINE_PORT = ${toString cfg.sunshinePort}
    STEAM_PORT = ${toString cfg.steamRemotePlayPort}
    DISPLAY_MODE_CONTROL = ${
      if cfg.enableDisplayModeControl
      then "True"
      else "False"
    }
    AWAY_MODE_COMMAND = ${builtins.toJSON cfg.desktopAwayModeCommand}
    HOME_MODE_COMMAND = ${builtins.toJSON cfg.desktopHomeModeCommand}
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


    def poweroff_desktop():
        try:
            subprocess.run(
                [
                    "${pkgs.openssh}/bin/ssh",
                    "-o", "StrictHostKeyChecking=accept-new",
                    "-o", "ConnectTimeout=5",
                    f"{DESKTOP_USER}@{DESKTOP_IP}",
                    "sudo", "poweroff",
                ],
                timeout=10,
                capture_output=True,
            )
        except (subprocess.TimeoutExpired, OSError):
            pass


    def run_display_mode_command(command):
        if not DISPLAY_MODE_CONTROL:
            return False
        try:
            result = subprocess.run(
                [
                    "${pkgs.openssh}/bin/ssh",
                    "-o", "StrictHostKeyChecking=accept-new",
                    "-o", "ConnectTimeout=5",
                    f"{DESKTOP_USER}@{DESKTOP_IP}",
                    command,
                ],
                timeout=15,
                capture_output=True,
                text=True,
            )
            return result.returncode == 0
        except (subprocess.TimeoutExpired, OSError):
            return False


    def get_display_mode():
        if not DISPLAY_MODE_CONTROL:
            return "unsupported"
        try:
            result = subprocess.run(
                [
                    "${pkgs.openssh}/bin/ssh",
                    "-o", "StrictHostKeyChecking=accept-new",
                    "-o", "ConnectTimeout=5",
                    f"{DESKTOP_USER}@{DESKTOP_IP}",
                    "sudo", "/run/current-system/sw/bin/desktop-display-mode", "status",
                ],
                timeout=10,
                capture_output=True,
                text=True,
            )
            if result.returncode != 0:
                return "unknown"
            mode = result.stdout.strip().lower()
            if mode in ["home", "away", "unknown"]:
                return mode
            return "unknown"
        except (subprocess.TimeoutExpired, OSError):
            return "unknown"


    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path == "/api/status":
                online = desktop_online()
                sunshine = check_port(DESKTOP_IP, SUNSHINE_PORT) if online else False
                steam = check_port(DESKTOP_IP, STEAM_PORT) if online else False
                display_mode = get_display_mode() if online else "unknown"
                self._send_json({
                    "desktop": "online" if online else "offline",
                    "sunshine": "running" if sunshine else "stopped",
                    "steam": "running" if steam else "stopped",
                    "display_mode_control": DISPLAY_MODE_CONTROL,
                    "display_mode": display_mode,
                })
            elif self.path == "/":
                self._send_html(HTML)
            else:
                self.send_error(404)

        def do_POST(self):
            if self.path == "/api/wake":
                threading.Thread(target=wake_desktop, daemon=True).start()
                self._send_json({"status": "waking"})
            elif self.path == "/api/poweroff":
                threading.Thread(target=poweroff_desktop, daemon=True).start()
                self._send_json({"status": "powering_off"})
            elif self.path == "/api/mode/away":
                success = run_display_mode_command(AWAY_MODE_COMMAND)
                self._send_json({"status": "away_requested" if success else "away_failed", "ok": success})
            elif self.path == "/api/mode/home":
                success = run_display_mode_command(HOME_MODE_COMMAND)
                self._send_json({"status": "home_requested" if success else "home_failed", "ok": success})
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
      .dot.home{background:#4ecca3;box-shadow:0 0 8px #4ecca3}
      .dot.away{background:#ffd369;box-shadow:0 0 8px #ffd369}
      .dot.unknown{background:#555;box-shadow:0 0 4px #555}
      .dot.waking{background:#ffd369;box-shadow:0 0 8px #ffd369;animation:pulse 0.6s ease-in-out infinite}
      @keyframes pulse{50%{opacity:0.3}}
      .status-label{font-size:0.875rem;color:#ccc}
      .status-label strong{color:#eee}
      button{width:100%;padding:1rem;border:none;border-radius:0.5rem;font-size:1rem;font-weight:600;cursor:pointer;background:#e94560;color:#fff;transition:background 0.15s;margin-bottom:0.75rem}
      button:hover{background:#d63851}
      button:disabled{opacity:0.4;cursor:not-allowed}
      button.danger{background:#a00}
      button.danger:hover{background:#c22}
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
          <span class="dot unknown" id="dotDisplayMode"></span>
          <span class="status-label" id="labelDisplayMode">Display mode: --</span>
        </div>
        <div class="status-row">
          <span class="dot unknown" id="dotSunshine"></span>
          <span class="status-label" id="labelSunshine">Sunshine: --</span>
        </div>
        <div class="status-row">
          <span class="dot unknown" id="dotSteam"></span>
          <span class="status-label" id="labelSteam">Steam: --</span>
        </div>
      </div>
      <button id="wakeBtn" onclick="wake()">Wake Desktop</button>
      <button id="awayBtn" onclick="setAwayMode()">Switch To Virtual Display</button>
      <button id="homeBtn" onclick="setHomeMode()">Switch To Physical Display</button>
      <button id="poweroffBtn" class="danger" onclick="poweroff()">Power Off</button>
      <div class="error" id="error"></div>
    </div>
    <script>
      async function refresh() {
        try {
          const r = await fetch("/api/status");
          const d = await r.json();
          const online = d.desktop === "online";
          document.getElementById("dotDesktop").className = "dot " + d.desktop;
          document.getElementById("labelDesktop").innerHTML = "<strong>Desktop</strong> " + (online ? "online" : "offline");
          document.getElementById("dotSunshine").className = "dot " + (online ? d.sunshine : "unknown");
          document.getElementById("labelSunshine").innerHTML = "<strong>Sunshine</strong> " + (online ? d.sunshine : "--");
          document.getElementById("dotSteam").className = "dot " + (online ? d.steam : "unknown");
          document.getElementById("labelSteam").innerHTML = "<strong>Steam</strong> " + (online ? d.steam : "--");
          const mode = online ? (d.display_mode || "unknown") : "unknown";
          document.getElementById("wakeBtn").disabled = online;
          document.getElementById("poweroffBtn").disabled = !online;
          const modeControlEnabled = !!d.display_mode_control;
          document.getElementById("labelDisplayMode").innerHTML = modeControlEnabled
            ? "<strong>Display mode</strong> " + mode
            : "<strong>Display mode</strong> unsupported";
          document.getElementById("dotDisplayMode").className = "dot " + (modeControlEnabled ? mode : "unknown");
          document.getElementById("awayBtn").disabled = !online || !modeControlEnabled;
          document.getElementById("homeBtn").disabled = !online || !modeControlEnabled;
          document.getElementById("awayBtn").style.display = modeControlEnabled ? "block" : "none";
          document.getElementById("homeBtn").style.display = modeControlEnabled ? "block" : "none";
        } catch(e) {
          document.getElementById("labelDesktop").innerHTML = "<strong>Desktop</strong> connection error";
        }
      }
      async function setAwayMode() {
        document.getElementById("awayBtn").disabled = true;
        document.getElementById("error").style.display = "none";
        try {
          const r = await fetch("/api/mode/away", { method: "POST" });
          const d = await r.json();
          if (!d.ok) throw new Error("away failed");
          setTimeout(refresh, 3000);
        } catch(e) {
          document.getElementById("error").textContent = "Failed to switch to virtual display";
          document.getElementById("error").style.display = "block";
        } finally {
          setTimeout(refresh, 1000);
        }
      }
      async function setHomeMode() {
        document.getElementById("homeBtn").disabled = true;
        document.getElementById("error").style.display = "none";
        try {
          const r = await fetch("/api/mode/home", { method: "POST" });
          const d = await r.json();
          if (!d.ok) throw new Error("home failed");
          setTimeout(refresh, 3000);
        } catch(e) {
          document.getElementById("error").textContent = "Failed to switch to physical display";
          document.getElementById("error").style.display = "block";
        } finally {
          setTimeout(refresh, 1000);
        }
      }
      async function wake() {
        document.getElementById("wakeBtn").disabled = true;
        document.getElementById("dotDesktop").className = "dot waking";
        document.getElementById("labelDesktop").innerHTML = "<strong>Desktop</strong> waking...";
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
      async function poweroff() {
        if (!confirm("Power off the desktop?")) return;
        document.getElementById("poweroffBtn").disabled = true;
        document.getElementById("error").style.display = "none";
        try {
          await fetch("/api/poweroff", { method: "POST" });
          document.getElementById("labelDesktop").innerHTML = "<strong>Desktop</strong> powering off...";
          setTimeout(refresh, 5000);
        } catch(e) {
          document.getElementById("error").textContent = "Failed to send power off command";
          document.getElementById("error").style.display = "block";
          document.getElementById("poweroffBtn").disabled = false;
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
      default = inputs.self.lib.hosts.desktop.ip or "192.168.178.3";
      description = "IP address of the desktop to control";
    };

    desktopUser = lib.mkOption {
      type = lib.types.str;
      default = "schausberger";
      description = "Username on the desktop for SSH power off";
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
      default = 47990;
      description = "Sunshine HTTP port on the desktop for status checks";
    };

    steamRemotePlayPort = lib.mkOption {
      type = lib.types.port;
      default = 27036;
      description = "Steam Remote Play port on the desktop for status checks";
    };

    enableDisplayModeControl = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable remote switching between desktop home/away display modes";
    };

    desktopAwayModeCommand = lib.mkOption {
      type = lib.types.str;
      default = "sudo /run/current-system/sw/bin/desktop-display-mode away";
      description = "Command executed via SSH on desktop to switch to virtual display mode";
    };

    desktopHomeModeCommand = lib.mkOption {
      type = lib.types.str;
      default = "sudo /run/current-system/sw/bin/desktop-display-mode home";
      description = "Command executed via SSH on desktop to switch to physical display mode";
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
      path = [pkgs.openssh];
      serviceConfig = {
        ExecStart = "${pkgs.python3}/bin/python3 ${webServer}";
        Restart = "always";
        RestartSec = "5";
        DynamicUser = lib.mkForce false;
        User = cfg.desktopUser;
        Group = "users";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
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
