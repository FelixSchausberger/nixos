# WSL2 headless host with NixOS userland, corporate CA integration, and TUI tools.
# Replaces unsupported bare-metal features (ZFS/bootloader) with WSL-safe equivalents.
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  hostName = "hp-probook-wsl";
  hostInfo = inputs.self.lib.hosts.${hostName};
in {
  imports = [
    ../shared-tui.nix
    inputs.nixos-wsl.nixosModules.default
    inputs.stylix.nixosModules.stylix
    ../../modules/system/stylix-catppuccin.nix
    ../../modules/system/wsl-integration.nix
    ../../modules/system/homelab/tailscale.nix
    ../../modules/vitals.nix
  ];
  config = {
    # Central WSL configuration (including mirrored networking + DNS)
    wsl = {
      enable = true;

      # All wslConf options defined once here
      wslConf = {
        automount.root = "/mnt";

        # Set to false to avoid Windows PATH pollution in Linux shells
        # Windows binaries are still accessible via interop.includePath
        # If you need Windows tools in PATH, set this to true
        interop.appendWindowsPath = false;
        interop.enabled = true;

        network.generateHosts = false; # Do not let WSL overwrite /etc/hosts
        network.generateResolvConf = true; # Let WSL generate /etc/resolv.conf for NAT-mode DNS
        network.hostname = hostName;

        user.default = config.hostConfig.user;
      };

      defaultUser = config.hostConfig.user;

      # Enable interop for Windows binary execution
      interop.includePath = true;

      # Integration with Docker Desktop disabled (using native docker)
      docker-desktop.enable = false;

      # WSLg disabled — this is a headless/TUI-only environment

      # Make grep available at /bin/grep during early boot
      # nixos-wsl's systemd-shim scripts may call bare grep before full PATH is set
      extraBin = [
        {
          src = "${pkgs.gnugrep}/bin/grep";
          name = "grep";
        }
      ];
    };

    # ESET SSL Filter CA certificate from sops
    sops.secrets."eset-root.pem" = {
      owner = "root";
      mode = "0444";
    };

    # Systemd service to create ESET-enhanced CA bundle at boot
    # Runs after sops secrets are available, before nix-daemon starts
    systemd.services.eset-ca-bundle = {
      description = "Create CA bundle with ESET SSL Filter cert";
      wantedBy = ["multi-user.target"];
      before = ["nix-daemon.service"];
      after = ["sops-nix.service"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };

      script = ''
        # Create composed bundle in /run (tmpfs, writable)
        umask 022
        cat ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
            ${config.sops.secrets."eset-root.pem".path} \
          > /run/ca-bundle-plus-eset.pem
        chmod 644 /run/ca-bundle-plus-eset.pem
        echo "Created ESET-enhanced CA bundle at /run/ca-bundle-plus-eset.pem"
      '';
    };

    # Host-specific configuration using centralized host mapping
    hostConfig = {
      inherit hostName;
      inherit (hostInfo) isGui;
      inherit (hostInfo) wms;
      # user and system use defaults from lib/defaults.nix
    };

    modules.system.stylix-catppuccin.enable = true;

    services.vitals = {
      enable = true;
      headless = true;
    };

    # WSL uses its own boot mechanism, disable systemd-boot from shared-gui.nix
    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

    # Disable ZFS configuration from boot-zfs.nix (WSL kernel doesn't support ZFS)
    boot.supportedFilesystems = lib.mkForce ["ntfs"];
    boot.zfs.extraPools = lib.mkForce [];
    services.zfs.autoScrub.enable = lib.mkForce false;
    services.zfs.autoSnapshot.enable = lib.mkForce false;

    # WSL uses ext4, not ZFS - disable persistence from system/core
    environment.persistence = lib.mkForce {};

    # XDG not needed — headless TUI environment

    # Emergency recovery user - minimal shell, no customization
    users.users.emergency = {
      isNormalUser = true;
      description = "Emergency recovery account";
      shell = pkgs.bash;
      extraGroups = ["wheel"]; # sudo access for recovery
      hashedPasswordFile = config.sops.secrets."private/password-hash".path;
      home = "/home/emergency";
    };

    # Enable user lingering for systemctl --user support (required for home-manager activation)
    # Previously disabled due to SIGCHLD issues with the GUI shell wrapper; safe now that WSL is headless.
    users.users.${config.hostConfig.user}.linger = true;

    # Merged modules configuration
    modules.system = {
      containers.enable = true;
      wsl-integration.enable = true;
      homelab.tailscale.enable = true;
      maintenance = {
        enable = true;
        autoUpdate.enable = false; # Disable auto-updates in WSL environment
        monitoring = {
          enable = true;
          alerts = false; # Disable alerts in WSL
        };
      };
      deploymentValidation = {
        # /run/current-system/sw/bin/systemctl omitted: on WSL each boot is fresh,
        # so /run/current-system is not available during pre-activation
        essentialPaths = [
          "/run/current-system/sw/bin/bash"
          "/nix/store"
        ];
      };
    };

    # Network configuration optimized for WSL (high level)
    networking = {
      inherit hostName;
      # Static nameservers removed — WSL generates /etc/resolv.conf in NAT mode
      nameservers = lib.mkForce [];
      # Disable NetworkManager in WSL
      networkmanager.enable = lib.mkForce false;
    };

    # systemd tweaks for WSL
    systemd = {
      services = {
        "NetworkManager-wait-online".enable = false;
        "systemd-networkd-wait-online".enable = lib.mkForce false;
        "smartd".enable = false;

        # home-manager activation takes ~9s on first boot and blocks
        # multi-user.target via Before=systemd-user-sessions.service, which
        # exceeds WSL's 10s boot timeout. Remove the Before constraint so it
        # runs asynchronously without blocking the boot target.
        home-manager-schausberger.before = lib.mkForce [];
      };

      # WSL-specific system directories (override shared-tui paths)
      tmpfiles.rules = let
        inherit (inputs.self.lib.defaults.system) user; # schausberger user ID (WSL base image UID)
      in [
        "d /home/${user}/mnt 0755 ${user} users -"
        "d /home/${user}/mnt/gdrive 0755 ${user} users -"
        # NOTE: XDG_RUNTIME_DIR is usually created automatically by systemd
        # This is a fallback to ensure it exists for WSL edge cases
        # Ensure sops key is readable by user (required for user-level sops-nix)
        "Z /per/system/sops-key.txt 0644 root root -"
        # Provide tzdata at standard path for WSL compatibility
        "L /usr/share/zoneinfo - - - - ${pkgs.tzdata}/share/zoneinfo"
        # Adjust /var/empty permissions without failing on WSL (chmod not supported)
        "z /var/empty 0555 root root -"
      ];
    };

    # Environment packages and tools
    environment = {
      systemPackages = with pkgs; [
        util-linux
        inetutils
        dnsutils

        psmisc
        strace
        lsof
      ];

      # No GUI session variables — headless TUI environment
    };

    # Nix configuration for WSL
    nix = {
      settings = {
        auto-optimise-store = true;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        connect-timeout = lib.mkForce 10;

        # Use ESET-enhanced bundle (created by systemd service at boot)
        ssl-cert-file = lib.mkForce "/run/ca-bundle-plus-eset.pem";
      };

      extraOptions = ''
        keep-env-derivations = true
        keep-outputs = true
      '';
    };

    # Git configuration to use ESET-enhanced bundle
    programs.git = {
      enable = true;
      config.http.sslCAInfo = "/run/ca-bundle-plus-eset.pem";
    };

    # nix-ld not needed — no GUI applications in headless TUI environment

    # Deploy minimal WezTerm config to Windows so native WezTerm sees the WSL
    # launch entries and SSH hosts. Only WSL-specific settings and launcher
    # entries go here — visual preferences (color scheme, opacity, font, etc.)
    # are Windows-side decisions and should not be dictated by Nix.
    #
    # SSH host labels and names are not sensitive — they match what is already
    # in the Windows ~/.ssh/config which WezTerm reads for SSH domain resolution.
    home-manager.users.${config.hostConfig.user} = {
      xdg.configFile."wezterm/wezterm.lua".text = ''
        local wezterm = require("wezterm")
        local config = wezterm.config_builder()

        -- Window sizing to avoid the tiny default window
        config.initial_cols = 160
        config.initial_rows = 48
        config.font_size = 11.0

        -- Default domain so new tabs open in WSL NixOS
        config.default_domain = "WSL:NixOS"

        -- Suppress auto-generated SSH domain entries from ~/.ssh/config.
        -- Without this, WezTerm creates a launcher entry for every Host in
        -- the SSH config (28 entries), flooding the launcher menu.
        config.ssh_domains = {}

        -- Add launcher on Ctrl+Shift+S (Ctrl+Shift+L is the debug overlay by default)
        local keys = wezterm.gui.default_keys()
        table.insert(keys, { key = "S", mods = "CTRL|SHIFT", action = wezterm.action.ShowLauncher })
        config.keys = keys

        -- Helper: SSH entry via native Windows cmd (no WSL hop).
        -- Uses cmd.exe /k so the tab stays open after ssh exits.
        local function ssh(label, host)
          return { label = label, args = { "cmd.exe", "/k", "ssh", host } }
        end

        config.launch_menu = {
          -- WSL entries: zellij and herdr run inside NixOS WSL.
          -- sleep 0.2 lets WezTerm's ConPTY settle from its initial 80x24 to the
          -- actual window dimensions before resize -q queries TIOCGWINSZ. Without
          -- the sleep, resize -q reads the stale 80x24 and zellij starts at that
          -- size with no subsequent SIGWINCH to correct it.
          {
            label = "WSL: Zellij",
            args = {
              "wsl.exe", "-d", "NixOS", "--",
              "/etc/profiles/per-user/${config.hostConfig.user}/bin/fish", "-l", "-c",
              "sleep 0.2; resize -q 2>/dev/null | source 2>/dev/null; exec zellij attach --create homelab-wsl", # nocheck: dangerous-shell-patterns
            },
          },
          {
            label = "WSL: Herdr",
            args = {
              "wsl.exe", "-d", "NixOS", "--",
              "/etc/profiles/per-user/${config.hostConfig.user}/bin/fish", "-l", "-c",
              -- sleep 0.2 gives the ConPTY time to settle so ratatui can enter
              -- raw mode on a stable PTY (prevents ENXIO on tcsetattr).
              "sleep 0.2; exec ${pkgs.herdr}/bin/herdr",
            },
          },

          -- Private / homelab hosts
          ssh("SSH: m920q",   "m920q"),
          ssh("SSH: desktop", "desktop"),

          -- Corporate: direct key-auth hosts (FVCS3)
          ssh("SSH: fvcs3-cwp-001", "fvcs3-cwp-001"),
          ssh("SSH: fvcs3-cwp-002", "fvcs3-cwp-002"),
          ssh("SSH: fvcs3-cwp-003", "fvcs3-cwp-003"),
          ssh("SSH: fvcs3-cwp-004", "fvcs3-cwp-004"),
          ssh("SSH: fvcs3-app-002", "fvcs3-app-002"),

          -- Corporate: direct key-auth hosts (FVCS4)
          ssh("SSH: fvcs4-cwp-001", "fvcs4-cwp-001"),
          ssh("SSH: fvcs4-cwp-002", "fvcs4-cwp-002"),
          ssh("SSH: fvcs4-cwp-003", "fvcs4-cwp-003"),
          ssh("SSH: fvcs4-cwp-004", "fvcs4-cwp-004"),
          ssh("SSH: fvcs4-cwp-005", "fvcs4-cwp-005"),
          ssh("SSH: fvcs4-cwp-006", "fvcs4-cwp-006"),

          -- Corporate: jump hosts
          ssh("SSH: fvcs-jh",  "fvcs-jh"),
          ssh("SSH: jumphost", "jumphost"),

          -- Corporate: interior hosts via jump host (ProxyCommand in ~/.ssh/config)
          ssh("SSH: fvcs3-mgt-001", "fvcs3-mgt-001"),
          ssh("SSH: fvcs3-mgt-002", "fvcs3-mgt-002"),
          ssh("SSH: fvcs3-app-001", "fvcs3-app-001"),
          ssh("SSH: fvcs3-mwp-001", "fvcs3-mwp-001"),
          ssh("SSH: fvcs3-swp-001", "fvcs3-swp-001"),
          ssh("SSH: fvcs4-mgt-001", "fvcs4-mgt-001"),
          ssh("SSH: fvcs4-mgt-002", "fvcs4-mgt-002"),
          ssh("SSH: fvcs4-app-001", "fvcs4-app-001"),
          ssh("SSH: fvcs4-app-002", "fvcs4-app-002"),
          ssh("SSH: fvcs4-mwp-001", "fvcs4-mwp-001"),
          ssh("SSH: fvcs4-swp-001", "fvcs4-swp-001"),

          -- Network gear (password auth)
          ssh("SSH: faax10-sw1", "faax10-sw1"),
        }

        return config
      '';

      # Named with zz- prefix to run after writeBoundary (alphabetical ordering)
      home.activation.zz-wezterm-windows-deploy = ''
        WEZTERM_TARGET="/mnt/c/Users/SchausbergerF/.config/wezterm/wezterm.lua"

        if [ -f "$HOME/.config/wezterm/wezterm.lua" ] && [ -d "/mnt/c/Users/SchausbergerF" ]; then
          mkdir -p "$(dirname "$WEZTERM_TARGET")"
          cp "$HOME/.config/wezterm/wezterm.lua" "$WEZTERM_TARGET"
        fi
      '';
    };
  };
}
