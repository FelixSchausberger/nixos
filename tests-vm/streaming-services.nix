# NixOS VM Integration Test: Moonshine Host, Moonlight Client & AirPlay Discovery
#
# Validates that the Moonshine wrapper module correctly configures the
# upstream NixOS module (firewall, service, user). Uses the real
# moonshine flake's NixOS module for option definitions — no port stubs.
#
# The client-side modules (airplay-receiver, media-client) are not imported
# because airplay-receiver starts uxplay as a systemd user service bound
# to graphical-session.target, which does not exist in a headless test VM.
# Avahi configuration is replicated manually to test the same functionality.
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
      };
    };

    client = {pkgs, ...}: {
      environment.systemPackages = [
        pkgs.curl
        pkgs.moonlight-qt
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

    # 1. Verify Moonshine NixOS module created the expected systemd unit
    server.succeed("systemctl list-unit-files | grep -q moonshine.service")

    # 2. Verify Moonshine mock service is running (real moonshine fails
    #    healthcheck without GPU in test VM — mock validates routing instead)
    server.wait_for_unit("mock-moonshine.service")
    server.wait_for_open_port(47989)

    # 3. Verify Moonlight client package is installed on client
    client.succeed("which moonlight")

    # 4. Verify Avahi daemon on client for AirPlay discovery
    client.wait_for_unit("avahi-daemon.service")
    client.succeed("avahi-daemon -c")

    # 5. Verify network communication from client to Moonshine server
    client.succeed("curl -s http://server:47989/ | grep -q 'mock-moonshine'")
  '';
}
