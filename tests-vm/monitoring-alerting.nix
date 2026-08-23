# NixOS VM Integration Test: Monitoring alert pipeline end-to-end.
#
# Boots Prometheus + Grafana + ntfy-sh with the production monitoring
# module, then verifies the full alert path that page delivery depends on:
# stopping an exporter must produce a properly formatted ntfy publish
# ([FIRING] title, severity-derived priority, tags), and restarting it must
# produce the matching resolve message. This is the only layer that catches
# provisioning-load errors and Grafana version drift breaking rendering.
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

  nodes.machine = {lib, ...}: {
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

      # Throwaway identity decrypting the fixture secrets; never used outside
      # this test.
      sops = {
        defaultSopsFile = ./fixtures/monitoring/secrets.yaml;
        age.keyFile = "/etc/monitoring-test-age-key";
        age.generateKey = false;
      };
      environment.etc."monitoring-test-age-key".source =
        ./fixtures/monitoring/test-age-key.txt;

      # The ntfy module stores state under /per (impermanence root on real
      # hosts); create it directly here.
      systemd.tmpfiles.rules = [
        "d /per/var/lib/ntfy-sh 0700 ntfy-sh ntfy-sh -"
      ];

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
    machine.wait_for_unit("prometheus-postgres-exporter.service")
    machine.wait_for_unit("grafana.service")
    machine.wait_for_unit("ntfy-sh.service")

    # Grafana waits for Prometheus itself; give the web UI a moment more.
    machine.wait_until_succeeds(
        "curl -sf http://127.0.0.1:3001/api/health | jq -e .database"
    )

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

    print("subtest: provisioned rules match the expected set")
    rules = json.loads(
        machine.succeed(
            "curl -sf -u 'admin:vm-test-grafana-admin-password' "
            "http://127.0.0.1:3001/api/v1/provisioning/alert-rules"
        )
    )
    uids = sorted(r["uid"] for r in rules)
    assert uids == [
        "node-exporter-down",
        "postgres-down",
    ], f"unexpected provisioned rules: {uids}"

    # One full evaluation window must stay quiet while everything is up.
    print("subtest: healthy system sends no notifications")
    machine.sleep(150)
    count = len(ntfy_messages())
    assert count == 0, f"expected no notifications on healthy system, got {count}"

    print("subtest: stopped exporter produces formatted firing push")
    machine.systemctl("stop prometheus-node-exporter.service")

    def is_firing():
        return any(m.get("title", "").startswith("[FIRING") for m in ntfy_messages())

    poll_until(is_firing, "[FIRING] notification")
    fire = [m for m in ntfy_messages() if m.get("title", "").startswith("[FIRING")][-1]
    assert "NodeExporterDown" in fire["title"], fire["title"]
    assert fire["priority"] == 4, f"expected priority 4, got {fire['priority']}"
    assert "warning" in fire["tags"], fire["tags"]

    print("subtest: recovered exporter produces resolve push")
    machine.systemctl("start prometheus-node-exporter.service")

    def is_resolved():
        return any(m.get("title", "").startswith("[RESOLVED") for m in ntfy_messages())

    poll_until(is_resolved, "[RESOLVED] notification")
    done = [m for m in ntfy_messages() if m.get("title", "").startswith("[RESOLVED")][-1]
    assert "NodeExporterDown" in done["title"], done["title"]
    assert done["priority"] == 2, f"expected priority 2, got {done['priority']}"
    assert "white_check_mark" in done["tags"], done["tags"]
  '';
}
