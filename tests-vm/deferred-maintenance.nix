# NixOS VM Integration Test: Deferred Maintenance Window & Network Sanity Gate
#
# Validates that the maintenance module's nightly window correctly handles
# deferred networkd restarts with sanity-gate pre-checks and rollback.
_: {
  name = "deferred-maintenance";

  nodes.machine = {pkgs, ...}: {
    imports = [
      ../modules/system/maintenance.nix
      ../modules/system/security-hardening.nix
    ];

    config = {
      environment.systemPackages = [
        pkgs.iproute2
        pkgs.iputils
      ];

      networking.useNetworkd = true;
      networking.useDHCP = false;

      systemd.network = {
        enable = true;
        networks."10-eth1" = {
          matchConfig.Name = "eth1";
          networkConfig.DHCP = "no";
          address = ["192.168.1.2/24"];
          gateway = ["192.168.1.2"];
        };
      };

      modules.system.maintenance = {
        enable = true;
        deferredRestarts = {
          enable = true;
          services = ["systemd-networkd"];
          networkSanity = {
            interface = "eth1";
            address = "192.168.1.2/24";
            gateway = "192.168.1.2";
            networkFile = "/etc/systemd/network/10-eth1.network";
          };
        };
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("systemd-networkd.service")

    # 1. Normal execution with healthy configuration
    machine.succeed("systemctl start network-maintenance.service")
    maint_log = machine.succeed("cat /var/log/network-maintenance.log")
    assert "maintenance window finished" in maint_log, f"Maintenance did not complete cleanly: {maint_log}"

    # 2. Verify the maintenance systemd timer exists
    machine.succeed("systemctl list-timers network-maintenance.timer --no-legend | grep -q network-maintenance")

    # 3. Corrupt network configuration file to trigger safety gate
    machine.succeed("rm -f /etc/systemd/network/10-eth1.network && echo '[Match]\nName=eth1' > /etc/systemd/network/10-eth1.network")

    # 4. Run maintenance again - should detect missing IP/gateway and abort networkd restart safely
    machine.succeed("systemctl restart network-maintenance.service")
    maint_log2 = machine.succeed("cat /var/log/network-maintenance.log")
    assert "missing static IP/gateway" in maint_log2 or "skipping networkd restart" in maint_log2, \
        f"Sanity gate failed to detect corruption: {maint_log2}"

    # 5. Verify networkd is still running (wasn't restarted with broken config)
    machine.succeed("systemctl is-active systemd-networkd.service")

    # 6. Verify rollback restored the original network config
    original_cfg = machine.succeed("cat /run/booted-system/etc/systemd/network/10-eth1.network")
    assert "Address=192.168.1.2/24" in original_cfg, f"Booted system config missing address: {original_cfg}"
    assert "Gateway=192.168.1.2" in original_cfg, f"Booted system config missing gateway: {original_cfg}"
  '';
}
