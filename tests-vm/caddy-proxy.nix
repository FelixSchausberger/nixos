# NixOS VM Integration Test: Caddy Reverse Proxy & Homelab Interconnect
#
# Validates that the Caddy reverse proxy module generates correct routing
# config for homelab services. Port values are sourced from the canonical
# lib/homelab-ports.nix to prevent drift — any port change in a homelab
# module must update that file, and the namaka homelab-port-sync test
# validates the match.
#
# Heavy homelab services (Immich, Nextcloud, Monitoring) are not imported
# because they require databases, external storage, etc. Their port values
# are referenced via the shared homelabPorts attrset.
{inputs, ...}: {
  name = "caddy-proxy";

  nodes.machine = {
    lib,
    pkgs,
    ...
  }: let
    # Port values from the canonical source: lib/homelab-ports.nix
    ports = inputs.self.lib.homelabPorts;

    mkMockServer = name: port: message:
      pkgs.writeShellScript "mock-${name}" ''
        exec ${pkgs.python3}/bin/python3 -c "
        import http.server, socketserver
        class Handler(http.server.SimpleHTTPRequestHandler):
            def do_GET(self):
                self.send_response(200)
                self.send_header('Content-type', 'text/plain')
                self.end_headers()
                self.wfile.write(b'${message}\n')
        with socketserver.TCPServer(('127.0.0.1', ${toString port}), Handler) as httpd:
            httpd.serve_forever()
        "
      '';

    # Behaves like a BaseURL-configured Navidrome: it only answers under the
    # /navidrome prefix and replies to anything else (notably its unprefixed
    # root, what a prefix-stripping route forwards) with the root-absolute
    # redirect a BaseURL-less server emits. The containment check below fails
    # if that redirect ever reaches a client that entered under /navidrome/.
    mkNavidromeMock = port:
      pkgs.writeShellScript "mock-navidrome" ''
        exec ${pkgs.python3}/bin/python3 -c "
        import http.server, socketserver
        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path.startswith('/navidrome'):
                    body = b'Mock Navidrome Response\n'
                    self.send_response(200)
                    self.send_header('Content-type', 'text/plain')
                    self.send_header('Content-Length', str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                else:
                    self.send_response(302)
                    self.send_header('Location', '/app/')
                    self.end_headers()
        with socketserver.TCPServer(('127.0.0.1', ${toString port}), Handler) as httpd:
            httpd.serve_forever()
        "
      '';
  in {
    imports = [
      ../modules/system/homelab/caddy-proxy.nix
    ];

    options = {
      # Impermanence not available in test VM; caddy-proxy declares persistence
      environment.persistence = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
      };

      # Tailscale module not imported; caddy-proxy sets permitCertUid
      services.tailscale = {
        permitCertUid = lib.mkOption {
          type = lib.types.str;
          default = "";
        };
      };

      # Homelab service options referenced by caddy-proxy assertions.
      # These are the minimal stubs needed — real modules are not imported
      # because their configs require databases, external storage, etc.
      modules.system.homelab = {
        immich = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = ports.immich;
          };
        };
        navidrome = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = ports.navidrome;
          };
        };
        monitoring = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          grafanaPort = lib.mkOption {
            type = lib.types.port;
            default = ports.grafana;
          };
        };
        adguardhome = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = ports.adguard;
          };
        };
        nextcloud = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = ports.nextcloud;
          };
        };
        homepage = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
        };
      };
    };

    config = {
      environment.systemPackages = [pkgs.curl];

      # Mock upstreams on real ports from homelab modules
      systemd.services.mock-navidrome = {
        description = "Mock Navidrome";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStart = mkNavidromeMock ports.navidrome;
          Restart = "always";
        };
      };

      systemd.services.mock-adguard = {
        description = "Mock AdGuard";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStart = mkMockServer "adguard" ports.adguard "Mock AdGuard Response";
          Restart = "always";
        };
      };

      systemd.services.mock-immich = {
        description = "Mock Immich";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          ExecStart = mkMockServer "immich" ports.immich "Mock Immich Response";
          Restart = "always";
        };
      };

      modules.system.homelab.caddyProxy = {
        enable = true;
        # http:// prefix forces HTTP-only listener — required in test VMs
        # where Tailscale is not available for TLS certificate provisioning.
        tailnetDomain = "http://m920q.test.local";
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("mock-navidrome.service")
    machine.wait_for_unit("mock-adguard.service")
    machine.wait_for_unit("mock-immich.service")
    machine.wait_for_unit("caddy.service")

    # 1. Test Navidrome path routing
    machine.succeed("curl -s -H 'Host: m920q.test.local' http://127.0.0.1/navidrome/ | grep -q 'Mock Navidrome Response'")

    # 2. Redirect containment: following redirects from a prefixed path must
    # never leave that prefix. The mock answers its unprefixed root with the
    # root-absolute redirect a BaseURL-less Navidrome emits, so a route that
    # strips the prefix lands the client on /app/ outside /navidrome/.
    final = machine.succeed(
        "curl -sL -o /dev/null -w '%{url_effective}' -H 'Host: m920q.test.local' http://127.0.0.1/navidrome/"
    ).strip()
    assert final.endswith("/navidrome/"), f"redirect escaped the prefix: {final}"

    # 3. Test AdGuard path routing
    machine.succeed("curl -s -H 'Host: m920q.test.local' http://127.0.0.1/adguard/ | grep -q 'Mock AdGuard Response'")

    # 4. Test Immich catch-all route at root
    machine.succeed("curl -s -H 'Host: m920q.test.local' http://127.0.0.1/api/v1/ping | grep -q 'Mock Immich Response'")

    # 5. Test Nextcloud .well-known redirects
    res = machine.succeed("curl -s -I -H 'Host: m920q.test.local' http://127.0.0.1/.well-known/carddav")
    assert "/nextcloud/remote.php/dav" in res, f"Redirect failed: {res}"

    # 6. Verify Caddy is serving on port 80
    machine.succeed("curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1/ | grep -q '200'")

    # 7. Test the Homepage wallpaper static route serves the real image
    machine.succeed("curl -s -o /tmp/wallpaper.jpg -H 'Host: m920q.test.local' http://127.0.0.1/bg/appa_blurred.jpg")
    magic = machine.succeed("od -An -tx1 -N3 /tmp/wallpaper.jpg | tr -d ' \\n'")
    assert magic == "ffd8ff", f"wallpaper route did not serve a JPEG: {magic!r}"
  '';
}
