# Shared floor for live-ISO host configs (installer, installer-minimal, portable).
#
# One place for the infrastructure every ISO needs - alias-limiting overlays,
# ZFS boot support, /per wiring, repo symlink, SSH/NetworkManager defaults,
# sudo-rs conflict fix, stateVersion. Per-image behavior is expressed through
# the isoShared options below instead of copy-pasted branches (those blocks
# used to be triple-written and had already drifted).
{
  lib,
  inputs,
  modulesPath,
  config,
  pkgs,
  ...
}: {
  options.isoShared = {
    hostName = lib.mkOption {
      type = lib.types.str;
      description = "Host name of the live image";
    };
    isoName = lib.mkOption {
      type = lib.types.str;
      description = "Output ISO file name (image.fileName)";
    };
    volumeID = lib.mkOption {
      type = lib.types.str;
      description = "ISO volume ID (isoImage.volumeID)";
    };
    autoLoginUser = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Auto-login an empty-password schausberger on TTY1";
    };
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Image-specific packages appended to the base tool set";
    };
  };

  imports = [
    (modulesPath + "/installer/cd-dvd/installation-cd-minimal.nix")
    (inputs.self + "/hosts/default/10-sops.nix")
    (inputs.self + "/system/core")
    (inputs.self + "/system/hardware")
    (inputs.self + "/system/network.nix")
    (inputs.self + "/hosts/shared-tui.nix")
  ];

  config = let
    cfg = config.isoShared;
    authorizedKeysFile = ./installer/authorized_keys;
    hasAuthorizedKeys = builtins.pathExists authorizedKeysFile;

    # Optional WiFi bootstrap: SSID/PSK arrive through the environment at
    # build time and never touch the repository. getEnv is empty under pure
    # evaluation, so CI builds the plain image:
    #   NIXOS_INSTALLER_WIFI_SSID=... NIXOS_INSTALLER_WIFI_PSK=... \
    #     nix build --impure .#installer-iso-minimal
    wifiSsid = builtins.getEnv "NIXOS_INSTALLER_WIFI_SSID";
    wifiPsk = builtins.getEnv "NIXOS_INSTALLER_WIFI_PSK";
    hasWifi = wifiSsid != "" && wifiPsk != "";
  in {
    networking.hostName = cfg.hostName;

    # Isolate from removed nixpkgs aliases that would otherwise throw during
    # ISO evaluation somewhere in the transitive evaluation chain. Provide
    # redirects via overlays for any packages/scripts still using old names.
    nixpkgs.config.allowAliases = false;
    nixpkgs.overlays = [
      (final: _prev: {
        nixfmt-classic = final.nixfmt;
        nixfmt-rfc-style = final.nixfmt;
      })
      # ceph pulls python311 and breaks evaluation on current nixpkgs; the
      # ISO does not need ceph-enabled qemu.
      (_final: prev: {
        qemu = prev.qemu.override {ceph = null;};
      })
      # sops-nix requests the removed buildGo125Module alias; `allowAliases =
      # false` above strips out even the alias stub, so the ISO evaluation
      # dies with a missing-argument error. Map it onto the current Go
      # builder like the fleet overlay does.
      (_final: prev: {
        buildGo125Module = prev.buildGoModule;
      })
    ];

    # Live ISO: no persistent filesystem.
    environment.persistence = lib.mkForce {};

    boot = {
      supportedFilesystems = [
        "zfs"
        "ext4"
        "btrfs"
        "xfs"
        "ntfs"
      ];
      kernelModules = [
        "zfs"
      ];
    };

    users.users = {
      root = {
        hashedPassword = lib.mkForce null; # Clear inherited hashedPassword from system/core/users.nix
        password = "nixos"; # Default password for installer convenience
        openssh.authorizedKeys.keyFiles =
          lib.optionals hasAuthorizedKeys [authorizedKeysFile];
      };
    };

    services.getty.autologinUser = lib.mkIf cfg.autoLoginUser (lib.mkForce "schausberger");

    systemd.tmpfiles.rules = [
      "d /per 0755 root root -"
      "d /per/etc 0755 root root -"
      "d /per/system 0755 root root -"
    ];

    # The repository travels inside the ISO; recovery/install tooling finds
    # it at the fixed path via NIXOS_CONFIG_ROOT.
    system.activationScripts.installRepo = ''
      mkdir -p /per/etc
      ln -sfn ${inputs.self} /per/etc/nixos
    '';

    environment.sessionVariables = {
      NIXOS_CONFIG_ROOT = "/per/etc/nixos";
    };

    # Base tool set every image carries; install-remote partitions the target
    # with this pinned disko binary instead of re-fetching
    # github:nix-community/disko at install time (system-pinned, no network).
    environment.systemPackages =
      (with pkgs; [
        vim
        nano
        parted
        gptfdisk
        curl
        wget
        git
        tmux
        # Wireless bring-up tools. NetworkManager drives the association for
        # nmtui, but the CLI helpers are not on PATH by default and
        # wireless-only targets (laptops, Surface-class tablets) need them
        # when the association has to be done by hand.
        wpa_supplicant
        iw
        dhcpcd
      ])
      ++ [
        inputs.disko.packages.${pkgs.stdenv.hostPlatform.system}.disko
      ]
      ++ cfg.extraPackages;

    services.openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        # recovery-tools.nix hardens this to false; the live images want
        # password auth for convenience.
        PasswordAuthentication = lib.mkForce true;
      };
    };

    networking.networkmanager.enable = true;
    networking.wireless.enable = lib.mkForce false;
    networking.wireless.iwd.enable = lib.mkForce false;

    # mwifiex (Marvell 88W8897 in Surface Pro 2017-class tablets) drops scans
    # and associations under the card's default power saving.
    networking.networkmanager.wifi.powersave = false;

    # The 88W8897 also wedges when PCIe L1 substates engage; linux-surface
    # recommends keeping port PM off on these machines. Live image only.
    boot.kernelParams = ["pcie_port_pm=off"];

    # linux-firmware ships mrvl/pcie8897_uapsta.bin only zstd-compressed, and
    # the live kernel's firmware loader does not decompress it, leaving the
    # adapter without firmware (empty iw scan, no carrier). Ship the
    # uncompressed blob explicitly.
    hardware.firmware = [
      (pkgs.runCommand "mwifiex-8897-firmware" {} ''
        install -Dm644 ${pkgs.fetchurl {
          url = "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/mrvl/pcie8897_uapsta.bin";
          hash = "sha256-z09R9BvX701/5l+3a4oqCJe8cKB0K8SuoT2TsD//0Do=";
        }} $out/lib/firmware/mrvl/pcie8897_uapsta.bin
      '')
    ];

    # A baked profile lets wireless-only machines join the network without
    # console typing. ensureProfiles materialises it with NetworkManager's
    # required permissions; the environment.etc shortcut produced a
    # world-readable keyfile that NetworkManager silently ignored.
    networking.networkmanager.ensureProfiles.profiles = lib.optionalAttrs hasWifi {
      installer-wifi = {
        connection = {
          id = "installer-wifi";
          type = "wifi";
          autoconnect = true;
        };
        wifi = {
          mode = "infrastructure";
          ssid = wifiSsid;
        };
        wifi-security = {
          key-mgmt = "wpa-psk";
          psk = wifiPsk;
        };
        ipv4.method = "auto";
        ipv6.method = "auto";
      };
    };

    # Fix sudo-rs conflict: system/core picks sudo-rs, but nixpkgs
    # installation-device.nix sets security.sudo. Keep sudo only.
    security.sudo-rs.enable = lib.mkForce false;

    # Fix stateVersion conflict - use installer version
    system.stateVersion = lib.mkForce "26.05";

    image.fileName = cfg.isoName;
    isoImage.volumeID = cfg.volumeID;
    isoImage.makeEfiBootable = true;
    isoImage.makeUsbBootable = true;
  };
}
