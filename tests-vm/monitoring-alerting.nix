# NixOS VM Integration Test: Monitoring alert pipeline end-to-end.
#
# Boots Prometheus + Alertmanager + alertmanager-ntfy + ntfy-sh with the
# production monitoring module, then verifies the full alert path that page
# delivery depends on: stopping an exporter must produce a properly formatted
# ntfy publish (title naming the host, priority from the alert's `priority`
# label, tags), and restarting it must produce the matching resolve message.
# This is the only layer that catches a broken rule file, a wrong Alertmanager
# receiver, or a bridge/template regression that eval-level tests cannot see.
#
# Secrets come from tests-vm/fixtures/monitoring/: a throwaway age key plus a
# secrets.yaml encrypted to it. They secure nothing and exist only so
# sops-nix activation succeeds inside the VM. Fixtures live under tests-vm/
# because tests/ is scanned by namaka, where non-test directories break the
# loader.
{
  pkgs,
  inputs,
  ...
}: {
  name = "monitoring-alerting";

  nodes.machine = {
    config,
    lib,
    ...
  }: {
    imports = [
      ../modules/system/homelab/monitoring.nix
      ../modules/system/homelab/ntfy.nix
      inputs.sops-nix.nixosModules.sops
    ];

    # Homelab services whose options monitoring.nix reads but whose modules
    # are deliberately not imported here (databases, storage, DNS).
    # Impermanence is likewise absent in the test VM.
    options = {
      environment.persistence = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
      };
      modules.system.homelab = {
        adguardhome = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
          };
        };
        immich = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
          };
        };
        nextcloud = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 8080;
          };
        };
        backup.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        jellyfin.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        # monitoring.nix's navidrome probe references enable and port; the
        # probe itself stays out of the test (navidrome.enable defaults off).
        navidrome = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          port = lib.mkOption {
            type = lib.types.port;
            default = 4533;
          };
        };
        vaultwarden.enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
        };
        # garmin.nix reads these sibling options; the VM test does not import
        # the garmin module itself (no live Garmin credentials in CI).
        garmin = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          influxPort = lib.mkOption {
            type = lib.types.port;
            default = 8087;
          };
          calendar = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            user = lib.mkOption {
              type = lib.types.str;
              default = "admin";
            };
            interval = lib.mkOption {
              type = lib.types.str;
              default = "15min";
            };
          };
        };
        # monitoring.nix gates Grafana sub-path serving on the Caddy proxy
        # route; caddy-proxy.nix is not imported here (no proxy in the test
        # VM), so the route toggles stay off.
        caddyProxy = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
          grafana = lib.mkOption {
            type = lib.types.bool;
            default = false;
          };
        };
        # monitoring.nix's Prometheus serve-port assertion compares
        # prometheusHttpsPort against the Tailscale Serve ports of the three
        # modules that expose one; none of them is imported in this test VM.
        zellijWeb.httpsPort = lib.mkOption {
          type = lib.types.port;
          default = 8443;
        };
        opencodeWeb.httpsPort = lib.mkOption {
          type = lib.types.port;
          default = 8444;
        };
        homepage.httpsPort = lib.mkOption {
          type = lib.types.port;
          default = 8445;
        };
        # monitoring.nix feeds determinate-nixd GC data through
        # modules.system.maintenance, which the test node does not import (see
        # the modules.system.maintenance stub below).
      };
      modules.system.maintenance.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
      };
    };

    config = {
      modules.system.homelab.monitoring = {
        enable = true;
        alerting.enable = true;
        fritzbox.enable = false;
      };
      modules.system.homelab.ntfy.enable = true;

      services.postgresql.enable = true;
      # The postgres exporter (and its PostgresDown alert rule) is gated on
      # nextcloud.enable in monitoring.nix since 53e6db1. Enable the stub
      # options so the exporter starts and the PostgresDown rule is
      # provisioned; the secret it reads is in the fixture file.
      modules.system.homelab.nextcloud.enable = true;

      # Throwaway identity decrypting the fixture secrets; never used outside
      # this test.
      sops = {
        defaultSopsFile = ./fixtures/monitoring/secrets.yaml;
        age.keyFile = "/etc/monitoring-test-age-key";
        age.generateKey = false;
      };
      # The nextcloud exporter stub (enabled below) reads the admin password
      # through monitoring.nix; the fixture has no 'nextcloud' section, so
      # point its secret at an existing fixture key (values are throwaway;
      # the exporter only needs a readable file to start).
      users.users.nextcloud-exporter = {};
      sops.secrets."nextcloud/admin-password" = {
        key = "grafana/secret-key";
        owner = "nextcloud-exporter";
        mode = "0440";
      };
      environment.etc."monitoring-test-age-key".source =
        ./fixtures/monitoring/test-age-key.txt;

      # The ntfy module stores state under /per (impermanence root on real
      # hosts); create it directly here.
      systemd.tmpfiles.rules = [
        "d /per/var/lib/ntfy-sh 0700 ntfy-sh ntfy-sh -"
      ];

      # Static answer for the Nextcloud blackbox probe so the healthy-quiet
      # window stays quiet: Nextcloud itself is absent in this VM, and its
      # status.php probe would otherwise fire NextcloudDown. A plain 200 from
      # boot satisfies the probe.
      systemd.services.monitoring-test-status = {
        description = "Static status.php stub for the Nextcloud blackbox probe";
        wantedBy = ["multi-user.target"];
        serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server ${toString config.modules.system.homelab.nextcloud.port} --directory /var/lib/monitoring-test-status";
        preStart = ''
          mkdir -p /var/lib/monitoring-test-status
          echo '{"status":"ok"}' > /var/lib/monitoring-test-status/status.php
        '';
      };

      environment.systemPackages = with pkgs; [
        curl
        jq
      ];

      virtualisation.memorySize = 3072;
    };
  };

  testScript = ''
    import json

    start_all()
    machine.wait_for_unit("multi-user.target")

    machine.wait_for_unit("prometheus.service")
    machine.wait_for_unit("alertmanager.service")
    machine.wait_for_unit("alertmanager-ntfy.service")
    machine.wait_for_unit("prometheus-postgres-exporter.service")
    machine.wait_for_unit("ntfy-sh.service")

    def ntfy_messages():
        out = machine.succeed(
            "curl -sf 'http://127.0.0.1:2586/homelab-alerts/json?poll=1'"
        )
        return [json.loads(l) for l in out.splitlines() if l.strip()]

    def poll_until(check, description, timeout=420):
        # The typed test driver only accepts shell strings for
        # wait_until_succeeds, so poll in Python.
        import time

        deadline = time.time() + timeout
        while time.time() < deadline:
            if check():
                return
            machine.sleep(10)
        raise Exception(f"timed out waiting for {description}")

    print("subtest: loaded rules match the expected set")
    groups = json.loads(
        machine.succeed("curl -sf http://127.0.0.1:9090/api/v1/rules")
    )["data"]["groups"]
    names = sorted(
        r["name"] for g in groups for r in g["rules"] if r["type"] == "alerting"
    )
    # nextcloud.enable is on (the postgres exporter and its rule depend on it)
    # so NextcloudDown and PostgresDown load too. The status.php stub answers
    # the Nextcloud probe, keeping NextcloudDown quiet.
    assert names == [
        "FilesystemFull",
        "FilesystemWarn",
        "NextcloudDown",
        "NodeExporterDown",
        "PostgresDown",
    ], f"unexpected loaded rules: {names}"

    machine.sleep(150)
    print("subtest: healthy system sends no notifications")
    count = len(ntfy_messages())
    assert count == 0, f"expected no notifications on healthy system, got {count}"

    print("subtest: stopped exporter produces a formatted firing push")
    machine.systemctl("stop prometheus-node-exporter.service")

    def is_firing():
        return any(
            m.get("title", "").startswith("NodeExporterDown") for m in ntfy_messages()
        )

    poll_until(is_firing, "firing notification")
    fire = [
        m
        for m in ntfy_messages()
        if m.get("title", "").startswith("NodeExporterDown")
    ][-1]
    # The title names the source host; priority comes from the rule's
    # priority=urgent label, and the firing tag is attached.
    assert fire["title"].startswith("NodeExporterDown "), fire["title"]
    assert " on " in fire["title"], fire["title"]
    assert fire["priority"] == 5, f"expected priority 5, got {fire['priority']}"
    assert "rotating_light" in fire["tags"], fire["tags"]

    print("subtest: recovered exporter produces a resolve push")
    machine.systemctl("start prometheus-node-exporter.service")

    def is_resolved():
        return any(
            m.get("title", "").startswith("Resolved: NodeExporterDown")
            for m in ntfy_messages()
        )

    poll_until(is_resolved, "resolved notification")
    done = [
        m
        for m in ntfy_messages()
        if m.get("title", "").startswith("Resolved: NodeExporterDown")
    ][-1]
    # Resolved alerts drop to the default ntfy priority.
    assert done["priority"] == 3, f"expected priority 3, got {done['priority']}"
    assert "white_check_mark" in done["tags"], done["tags"]
  '';
}
