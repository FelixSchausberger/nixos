# NixOS VM Integration Test: ZFS Sanoid Snapshots & Syncoid Backup Pipeline
_: {
  name = "zfs-backup";

  nodes.machine = {pkgs, ...}: {
    imports = [
      ../modules/system/homelab/backup.nix
    ];

    boot.supportedFilesystems = ["zfs"];
    networking.hostId = "12345678";

    environment.systemPackages = [
      pkgs.sanoid
      pkgs.zfs
    ];

    # Configure backup module for test datasets
    modules.system.homelab.backup = {
      enable = true;
      sanoidDatasets = {
        "dpool/data" = {
          hourly = 24;
          daily = 7;
          weekly = 4;
          monthly = 12;
          yearly = 1;
          recursive = false;
        };
      };
      syncoidCommands = {
        "dpool-to-bpool" = {
          source = "dpool/data";
          target = "bpool/backup/data";
        };
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # 1. Verify backup module created the expected systemd services
    machine.succeed("systemctl list-unit-files | grep -q sanoid.service")
    machine.succeed("systemctl list-unit-files | grep -q syncoid-dpool-to-bpool.service")

    # 2. Create backing loop files for ZFS test pools
    machine.succeed("truncate -s 3G /var/dpool.raw && truncate -s 3G /var/bpool.raw")
    machine.succeed("zpool create dpool /var/dpool.raw")
    machine.succeed("zpool create bpool /var/bpool.raw")
    machine.succeed("zfs create dpool/data")
    machine.succeed("zfs create -p bpool/backup")

    # 3. Write initial data
    machine.succeed("echo 'homelab secret data' > /dpool/data/important.txt")

    # 4. Take Sanoid snapshot
    machine.succeed("sanoid --take-snapshots")
    snapshots = machine.succeed("zfs list -t snapshot")
    assert "dpool/data@autosnap" in snapshots, f"Expected snapshot not found: {snapshots}"

    # 5. Verify snapshot retention matches configured policy
    snap_count = machine.succeed("zfs list -t snapshot -o name | grep -c 'dpool/data@autosnap_'")
    assert int(snap_count) >= 1, f"Expected at least 1 snapshot, got {snap_count}"

    # 6. Run Syncoid replication service
    machine.succeed("systemctl start --wait syncoid-dpool-to-bpool.service")

    # Ensure dataset is mounted after replication
    machine.succeed("zfs mount -a")

    # 7. Verify replicated dataset exists and data is intact
    machine.succeed("test -f /bpool/backup/data/important.txt")
    content = machine.succeed("cat /bpool/backup/data/important.txt")
    assert "homelab secret data" in content, f"Replication content mismatch: {content}"
  '';
}
