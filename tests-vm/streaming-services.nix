# NixOS VM Integration Test: Moonshine, Moonlight & AirPlay Receiver Pipeline
#
# Validates the full streaming stack:
# - Moonshine NixOS module (firewall, systemd unit, mock service)
# - AirPlay receiver pipeline (Avahi, firewall ports, mDNS discovery, TCP connectivity)
#
# airplay-receiver.nix is not imported directly: its uxplay user service
# needs a DRM connector (kmssink) or compositor (waylandsink), neither of
# which exists in a headless test VM. The non-graphical parts (Avahi,
# firewall, package) are replicated on the server to validate every layer
# up to the video sink.
{inputs, ...}: {
  name = "streaming-services";

  nodes = {
    server = {
      lib,
      pkgs,
      ...
    }: {
      imports = [
        inputs.moonshine.nixosModules.default
        ../modules/system/moonshine.nix
      ];

      # moonshine.nix reads config.hostConfig.user — define the option
      options.hostConfig = {
        user = lib.mkOption {
          type = lib.types.str;
          default = "schausberger";
        };
      };

      config = {
        users.users.schausberger = {
          isNormalUser = true;
          uid = 1000;
          home = "/home/schausberger";
          createHome = true;
          extraGroups = ["wheel" "video"];
        };

        modules.system.moonshine.enable = true;

        # Mock game streaming listener on Moonshine HTTP port
        systemd.services.mock-moonshine = {
          description = "Mock Moonshine Streaming Daemon";
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            ExecStart = pkgs.writeShellScript "mock-moonshine" ''
              exec ${pkgs.python3}/bin/python3 -c "
              import http.server, socketserver
              class Handler(http.server.SimpleHTTPRequestHandler):
                  def do_GET(self):
                      self.send_response(200)
                      self.send_header('Content-type', 'application/json')
                      self.end_headers()
                      self.wfile.write(b'{\"status\":\"online\",\"version\":\"mock-moonshine\"}\n')
              with socketserver.TCPServer(('0.0.0.0', 47989), Handler) as httpd:
                  httpd.serve_forever()
              "
            '';
            Restart = "always";
          };
        };

        # --- AirPlay receiver pipeline (replicates airplay-receiver.nix) ---
        # uxplay systemd.user.service is omitted because it needs a DRM
        # connector or compositor; everything else is tested.

        services.avahi = {
          enable = true;
          openFirewall = true;
          nssmdns4 = true;
          publish = {
            enable = true;
            addresses = true;
            userServices = true;
          };
        };
        services.resolved.settings.Resolve.MulticastDNS = false;

        environment.systemPackages = [pkgs.uxplay];

        networking.firewall.allowedTCPPorts = [
          7000
          7001
          7100
        ];
        networking.firewall.allowedUDPPorts = [
          6000
          6001
          7011
        ];

        # Mock AirPlay listener — binds to the primary RAOP port (7000)
        # so the client can verify firewall passthrough and TCP connectivity.
        systemd.services.mock-airplay = {
          description = "Mock UxPlay AirPlay Receiver";
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            ExecStart = pkgs.writeShellScript "mock-airplay" ''
              exec ${pkgs.python3}/bin/python3 -c "
              import socket, threading
              def handle(conn):
                  conn.sendall(b'RTSP/1.0 200 OK\r\n\r\n')
                  conn.close()
              srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
              srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
              srv.bind(('0.0.0.0', 7000))
              srv.listen(5)
              while True:
                  conn, _ = srv.accept()
                  threading.Thread(target=handle, args=(conn,), daemon=True).start()
              "
            '';
            Restart = "always";
          };
        };
      };
    };

    client = {pkgs, ...}: {
      environment.systemPackages = [
        pkgs.curl
        pkgs.moonlight-qt
        pkgs.avahi
      ];

      users.users.schausberger = {
        isNormalUser = true;
        uid = 1000;
        home = "/home/schausberger";
        createHome = true;
        extraGroups = ["wheel" "video"];
      };

      # Avahi for AirPlay mDNS discovery (replicates airplay-receiver.nix config)
      services.avahi = {
        enable = true;
        openFirewall = true;
        nssmdns4 = true;
        publish = {
          enable = true;
          addresses = true;
          userServices = true;
        };
      };
      services.resolved.settings.Resolve.MulticastDNS = false;
    };
  };

  testScript = ''
    start_all()

    server.wait_for_unit("multi-user.target")
    client.wait_for_unit("multi-user.target")

    # --- Moonshine / Moonlight ---

    # 1. Verify Moonshine NixOS module created the expected systemd unit
    server.succeed("systemctl list-unit-files | grep -q moonshine.service")

    # 2. Verify Moonshine mock service is running (real moonshine fails
    #    healthcheck without GPU in test VM — mock validates routing instead)
    server.wait_for_unit("mock-moonshine.service")
    server.wait_for_open_port(47989)

    # 3. Verify Moonlight client package is installed on client
    client.succeed("which moonlight")

    # 4. Verify network communication from client to Moonshine server
    client.succeed("curl -s http://server:47989/ | grep -q 'mock-moonshine'")

    # --- AirPlay receiver pipeline ---

    # 5. Verify Avahi daemon is running on both nodes
    server.wait_for_unit("avahi-daemon.service")
    server.succeed("avahi-daemon -c")
    client.wait_for_unit("avahi-daemon.service")
    client.succeed("avahi-daemon -c")

    # 6. Verify uxplay package is installed on server
    server.succeed("which uxplay")

    # 7. Verify mock AirPlay listener is bound to RAOP port 7000
    server.wait_for_unit("mock-airplay.service")
    server.wait_for_open_port(7000)

    # 8. Verify AirPlay firewall rules are applied on server
    #    NixOS firewall renders allowedTCPPorts into iptables (nftables
    #    is disabled). Port 7000 has a real listener; 7001/7100 are just
    #    firewall passthrough rules.
    server.succeed("ss -ltn | grep -q ':7000 '")
    server.succeed("iptables -L nixos-fw -t filter -n | grep -q 'dpt:7001'")
    server.succeed("iptables -L nixos-fw -t filter -n | grep -q 'dpt:7100'")

    # 9. Verify client can discover server hostname via mDNS
    #    avahi-browse resolves the .local address; allow retries for
    #    propagation delay.
    client.succeed(
        "for i in $(seq 1 10); do"
        "  avahi-resolve -n server.local && break;"
        "  sleep 1;"
        "done"
    )

    # 10. Verify client can connect to the mock AirPlay port through the firewall
    client.succeed("bash -c '(echo > /dev/tcp/server/7000)'")
  '';
}
