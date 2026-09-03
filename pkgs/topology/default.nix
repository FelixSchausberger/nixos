{
  lib,
  d2,
  runCommand,
  writeText,
  m920qConfig,
}: let
  hl = m920qConfig.modules.system.homelab;

  # Service metadata: name → { label, port, category, color, caddyPath }
  # Port values come from the NixOS config options where available;
  # hardcoded for services without a configurable port.
  svcDefs = {
    adguardhome = {
      label = "AdGuard Home";
      port = hl.adguardhome.port;
      cat = "DNS";
      color = "#0984e3";
      caddy = "adguard";
    };
    immich = {
      label = "Immich";
      port = hl.immich.port;
      cat = "Media";
      color = "#6c5ce7";
      caddy = null;
    };
    nextcloud = {
      label = "Nextcloud";
      port = hl.nextcloud.port;
      cat = "Storage";
      color = "#00b894";
      caddy = "nextcloud";
    };
    navidrome = {
      label = "Navidrome";
      port = hl.navidrome.port;
      cat = "Media";
      color = "#e17055";
      caddy = "navidrome";
    };
    monitoring = {
      label = "Grafana";
      port = hl.monitoring.grafanaPort;
      cat = "Monitoring";
      color = "#fdcb6e";
      caddy = "grafana";
    };
    ntfy = {
      label = "ntfy.sh";
      port = 2586;
      cat = "Notifications";
      color = "#a29bfe";
      caddy = null;
    };
    zellijWeb = {
      label = "Zellij Web";
      port = hl.zellijWeb.port;
      cat = "Terminal";
      color = "#74b9ff";
      caddy = null;
    };
  };

  enabled = lib.filterAttrs (n: _: hl.${n}.enable or false) svcDefs;

  # D2: nested service nodes inside m920q container
  svcNodes = lib.concatStringsSep "\n" (lib.mapAttrsToList (n: s: ''
      ${n}: ${s.label} {
        style.fill: "${s.color}"
        style.font-color: white
        label: "${s.label}\n:${toString s.port}"
      }
    '')
    enabled);

  # D2: caddy route edges (conditional on caddyProxy + per-service toggle)
  caddyEdges = lib.concatStringsSep "\n" (lib.mapAttrsToList (
      n: s:
        lib.optionalString
        (s.caddy != null && hl.caddyProxy.enable && (hl.caddyProxy.${n} or false))
        ''
          caddy -> m920q.${n}: "/${s.caddy}"
        ''
    )
    enabled);

  # D2: monitoring scrape edges
  monitoringEdges = lib.optionalString hl.monitoring.enable ''
    prometheus -> m920q.node_exporter: scrape
    prometheus -> m920q.postgres_exporter: scrape
  '';

  d2Text = ''
      direction: down

      internet: Internet {
        shape: cloud
        style.fill: "#4a90d9"
        style.font-color: white
      }

      fritzbox: Fritz!Box 4050 {
        shape: rectangle
        style.fill: "#e8e8e8"
        style.font-color: "#333"
        style.border-radius: 4
        label: "Fritz!Box 4050\n192.168.178.1"
      }

      m920q: M920q Homelab {
        shape: rectangle
        style.fill: "#2d3436"
        style.font-color: "#dfe6e9"
        style.border-radius: 4
        label: "M920q Homelab\n192.168.178.2"
      ${svcNodes}
      }

      desktop: Desktop {
        shape: rectangle
        style.fill: "#00b894"
        style.font-color: white
        style.border-radius: 4
        label: "Desktop\n192.168.178.3"
      }

      tailscale: Tailscale {
        shape: cloud
        style.fill: "#00d2d3"
        style.font-color: "#333"
      }
    ${lib.optionalString hl.caddyProxy.enable ''
      caddy: Caddy {
        shape: hexagon
        style.fill: "#fdcb6e"
        style.font-color: "#333"
        label: "Caddy\n${hl.caddyProxy.tailnetDomain}"
      }
    ''}
    ${lib.optionalString hl.monitoring.enable ''
      prometheus: Prometheus {
        shape: circle
        style.fill: "#e67e22"
        style.font-color: white
        label: "Prometheus\n:9090"
      }
    ''}

      internet -> fritzbox: WAN
      fritzbox -> m920q: LAN
      fritzbox -> desktop: LAN
      m920q -> desktop: "SSH"
      tailscale -> m920q: tailnet
      tailscale -> desktop: tailnet
    ${caddyEdges}
    ${monitoringEdges}
  '';

  d2File = writeText "topology.d2" d2Text;

  # Inventory table rows for the HTML page
  inventoryRows = lib.concatMapStringsSep "\n" (s: ''
    <tr><td>${s.label}</td><td>${toString s.port}</td><td>${s.cat}</td></tr>
  '') (lib.attrValues enabled);

  htmlContent = ''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Homelab Topology</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: system-ui, -apple-system, sans-serif; background: #0f0f23; color: #e0e0e0; padding: 2rem; }
        h1, h2 { text-align: center; margin-bottom: 1rem; }
        .graph { text-align: center; margin: 2rem 0; }
        .graph img { max-width: 100%; height: auto; border: 1px solid #333; border-radius: 8px; }
        table { border-collapse: collapse; width: 100%; max-width: 800px; margin: 2rem auto; }
        th, td { border: 1px solid #333; padding: 0.75rem; text-align: left; }
        th { background: #16213e; font-weight: 600; }
        tr:hover { background: #1a1a2e; }
        footer { text-align: center; margin-top: 2rem; color: #666; font-size: 0.9rem; }
      </style>
    </head>
    <body>
      <h1>Homelab Topology</h1>
      <div class="graph">
        <img src="topology.svg" alt="Homelab network topology diagram">
      </div>
      <h2>Services Inventory</h2>
      <table>
        <tr><th>Service</th><th>Port</th><th>Category</th></tr>
        ${inventoryRows}
      </table>
      <footer>Auto-generated from NixOS configuration</footer>
    </body>
    </html>
  '';

  htmlFile = writeText "index.html" htmlContent;
in
  runCommand "homelab-topology" {
    nativeBuildInputs = [d2];
    passthru = {inherit d2Text enabled;};
  } ''
    mkdir -p $out
    ${d2}/bin/d2 --layout dagre ${d2File} $out/topology.svg
    cp ${htmlFile} $out/index.html
  ''
