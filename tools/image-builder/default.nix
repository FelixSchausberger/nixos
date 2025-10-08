{
  pkgs,
  config,
  ...
}: {
  # Custom ZFS-enabled image builder - imports handled by caller

  # ZFS support in installer
  boot.supportedFilesystems = ["zfs"];
  boot.kernelPackages = config.boot.zfs.package.latestCompatibleLinuxPackages;

  # Include our ZFS setup tool
  environment.systemPackages = with pkgs; [
    zfs
    parted
    gptfdisk
    # Custom installer script
    (writeShellScriptBin "nixos-zfs-install" ''
      # Automated installation script that uses your existing tool logic
      # but runs non-interactively with pre-configured host profiles
      exec ${../zfs-nixos-setup/target/release/zfs-nixos-setup} "$@"
    '')
  ];

  # Pre-configure flake source
  environment.etc."nixos-config-source".source = ../../.;

  # Auto-detect and install based on hardware
  systemd.services.auto-install = {
    description = "Auto-detect hardware and prompt for installation";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "auto-install" ''
        # Hardware detection logic
        if dmidecode -s system-product-name | grep -i "surface"; then
          PROFILE="surface"
        elif dmidecode -s system-product-name | grep -i "thinkpad"; then
          PROFILE="thinkpad"
        else
          PROFILE="portable"
        fi

        echo "Detected profile: $PROFILE"
        echo "Ready to install. Run: nixos-zfs-install --profile $PROFILE --disk /dev/sdX"
      '';
    };
  };
}
