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
  # nocheck: dangerous-shell-patterns
  # nocheck: dangerous-shell-patterns
  # "attach --create" panics when the server considers the session current.
  # list-sessions --no-formatting avoids ANSI codes in the match.
  # Attaching to a "(current)" session also panics — the (current) check skips that.
  # No exec — if zellij exits or crashes, the WezTerm tab stays open with fish.
  # Uses only single-quoted strings so the value embeds safely in a Lua double-quoted string.
  attachSession = config.hostConfig.zellijAutoAttach.sessionName;
  zellijCmd = ''
    set -l zs (zellij list-sessions --no-formatting 2>/dev/null | string match -r '^${attachSession}\b.*'); \
    if test (count $zs) -gt 0; \
      if not string match -rq '\(current\)' -- $zs; \
        zellij attach ${attachSession}; \
      end; \
    else; \
      zellij --session ${attachSession}; \
    end'';

  # Catppuccin Mocha color scheme for WezTerm, generated from the repo's color
  # definitions. Used instead of the built-in scheme name for robustness.
  weztermColors = let
    c = inputs.self.lib.catppuccinColors.mocha;
  in ''
    config.colors = {
      foreground = "${c.text}";
      background = "${c.base}";
      cursor_bg = "${c.rosewater}";
      cursor_border = "${c.rosewater}";
      cursor_fg = "${c.base}";
      selection_bg = "${c.surface0}";
      selection_fg = "${c.text}";
      ansi = {
        "${c.surface1}";
        "${c.red}";
        "${c.green}";
        "${c.yellow}";
        "${c.blue}";
        "${c.mauve}";
        "${c.teal}";
        "${c.subtext1}";
      };
      brights = {
        "${c.surface2}";
        "${c.red}";
        "${c.green}";
        "${c.yellow}";
        "${c.blue}";
        "${c.mauve}";
        "${c.teal}";
        "${c.subtext0}";
      };
    };
  '';
in {
  imports = [
    ../shared-tui.nix
    inputs.nixos-wsl.nixosModules.default
    inputs.stylix.nixosModules.stylix
    ../../modules/system/stylix-catppuccin.nix
    ../../modules/system/wsl-integration.nix
    ../../modules/system/tailscale.nix
    ../../modules/system/nixpkgs-overlays.nix # Disable flaky python-lsp-server/scipy checks
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

      zellijAutoAttach.sessionName = "homelab-wsl";
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

    # WSL has no /per dataset — sops reads SSH key from real home path
    sops.age.sshKeyPaths = lib.mkForce ["/home/schausberger/.ssh/id_ed25519"];

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
        monitoring = {
          enable = true;
          alerts = false; # Disable alerts in WSL
        };
      };
      # Pull-based GitOps: converge to main automatically. Alerts stay off,
      # matching the WSL monitoring policy; detections land in the journal.
      comin.enable = true;
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
        # Provide tzdata at standard path for WSL compatibility
        "L /usr/share/zoneinfo - - - - ${pkgs.tzdata}/share/zoneinfo"
        # Adjust /var/empty permissions without failing on WSL (chmod not supported)
        # NOTE: tmpfiles operations on WSL may fail due to missing filesystem
        # features. We avoid duplicate rules here and perform a best-effort chmod
        # from a oneshot service below.
      ];
    };

    # Ensure essential tools are available early during WSL activation so
    # activation scripts that call bare binaries (systemctl, grep) don't fail.
    system.activationScripts.wsl-early-bin = lib.stringAfter ["users"] ''
      mkdir -p /bin
      ln -sf ${pkgs.gnugrep}/bin/grep /bin/grep
      ln -sf ${pkgs.systemd}/bin/systemctl /bin/systemctl
    '';

    # Best-effort permissions hardening for /var/empty on WSL. We attempt the
    # chmod but never fail the boot if it is unsupported by the underlying fs.
    systemd.services.var-empty-perms = {
      description = "Best-effort /var/empty permission hardening (WSL)";
      after = ["systemd-tmpfiles-setup.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.coreutils}/bin/chmod 0555 /var/empty || true
      '';
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

    # Deploy WezTerm config to Windows with WSL launch entries, SSH hosts,
    # Catppuccin Mocha color scheme, and frosted-glass semi-transparency.
    #
    # SSH host labels and names are not sensitive — they match what is already
    # in the Windows ~/.ssh/config which WezTerm reads for SSH domain resolution.
    home-manager.users.${config.hostConfig.user} = {
      # Deploy Windows Terminal settings (incl. dssh profile) to the Windows side
      tui.windows-terminal.enable = true;

      # nocheck: dangerous-shell-patterns
      xdg.configFile."wezterm/wezterm.lua".text = ''
        local wezterm = require("wezterm")
        local config = wezterm.config_builder()

        -- Window sizing to avoid the tiny default window
        config.initial_cols = 160
        config.initial_rows = 48
        config.font_size = 11.0

        -- Prevent WezTerm from trying to resize the OS window when font size changes.
        -- When the window is maximized this attempt always fails (logged as a warning),
        -- and can cause Zellij to receive stale PTY dimensions at startup.
        config.adjust_window_size_when_changing_font_size = false

        -- Default domain so new tabs open in WSL NixOS
        config.default_domain = "WSL:NixOS"

        ${weztermColors}

        -- Semi-transparent background for frosted glass effect on Windows DWM
        config.window_background_opacity = 0.85

        -- Padding matching shared terminal module configuration
        config.window_padding = {
          left = 16,
          right = 16,
          top = 16,
          bottom = 16,
        }

        -- Suppress auto-generated SSH domain entries from ~/.ssh/config.
        -- Without this, WezTerm creates a launcher entry for every Host in
        -- the SSH config (28 entries), flooding the launcher menu.
        config.ssh_domains = {}

        -- Add launcher on Ctrl+Shift+S scoped to only our launch_menu entries
        -- (excludes built-in domains, workspaces, key-assignment commands, etc.)
        -- FUZZY activates type-to-filter directly; useful with many SSH hosts.
        if wezterm.gui then
          local keys = wezterm.gui.default_keys()
          table.insert(keys, {
            key = "S", mods = "CTRL|SHIFT",
            action = wezterm.action.ShowLauncherArgs {
              flags = "FUZZY|LAUNCH_MENU_ITEMS",
            },
          })
          config.keys = keys
        end

        -- Helper: SSH entry via native Windows cmd (no WSL hop).
        -- domain="local" is required: without it WezTerm inherits the window's
        -- default domain (WSL:NixOS) and tries to exec cmd.exe inside Linux.
        local function ssh(label, host)
          return {
            label  = label,
            domain = { DomainName = "local" },
            args   = { "cmd.exe", "/k", "ssh", host },
          }
        end

        config.launch_menu = {
          -- ── WSL ──────────────────────────────────────────────────────────
          -- sleep 0.2 lets WezTerm's ConPTY settle from its initial 80x24 to
          -- the actual window dimensions before resize -q queries TIOCGWINSZ.
          -- Without the sleep, resize -q reads the stale 80x24 and zellij starts at that
          -- size with no subsequent SIGWINCH to correct it.
          {
            label  = "WSL: Zellij",
            domain = { DomainName = "local" },
            args   = {
              "wsl.exe", "-d", "NixOS", "--",
              "/etc/profiles/per-user/${config.hostConfig.user}/bin/fish", "-l", "-c",
              [[${zellijCmd}]],
            },
          },
          {
            label  = "WSL: Herdr",
            domain = { DomainName = "local" },
            args   = {
              "wsl.exe", "-d", "NixOS", "--",
              "/etc/profiles/per-user/${config.hostConfig.user}/bin/fish", "-l", "-c",
              "sleep 0.2; exec ${pkgs.herdr}/bin/herdr",
            },
          },

          -- ── Windows ──────────────────────────────────────────────────────
          { label = "Windows: CMD",        domain = { DomainName = "local" }, args = { "cmd.exe" } },
          { label = "Windows: PowerShell", domain = { DomainName = "local" }, args = { "powershell.exe", "-NoLogo" } },

          -- ── Private / homelab ────────────────────────────────────────────
          ssh("Private: m920q",   "m920q"),
          ssh("Private: desktop", "desktop"),

          -- ── Homelab Zellij (web session) ─────────────────────────────────
          {
            label  = "Homelab: m920q Zellij",
            domain = { DomainName = "local" },
            args   = {
              "wsl.exe", "-d", "NixOS", "--",
              "/etc/profiles/per-user/${config.hostConfig.user}/bin/fish", "-l", "-c",
              "zr",
            },
          },

          -- ── Jump hosts ───────────────────────────────────────────────────
          ssh("Jumphost: fvcs-jh",  "fvcs-jh"),
          ssh("Jumphost: jumphost", "jumphost"),

          -- ── Switches ─────────────────────────────────────────────────────
          ssh("Switch: faax10-sw1", "faax10-sw1"),

          -- ── FVCS3 ────────────────────────────────────────────────────────
          ssh("FVCS3: cwp-001", "fvcs3-cwp-001"),
          ssh("FVCS3: cwp-002", "fvcs3-cwp-002"),
          ssh("FVCS3: cwp-003", "fvcs3-cwp-003"),
          ssh("FVCS3: cwp-004", "fvcs3-cwp-004"),
          ssh("FVCS3: app-001", "fvcs3-app-001"),
          ssh("FVCS3: app-002", "fvcs3-app-002"),
          ssh("FVCS3: mgt-001", "fvcs3-mgt-001"),
          ssh("FVCS3: mgt-002", "fvcs3-mgt-002"),
          ssh("FVCS3: mwp-001", "fvcs3-mwp-001"),
          ssh("FVCS3: swp-001", "fvcs3-swp-001"),

          -- ── FVCS4 ────────────────────────────────────────────────────────
          ssh("FVCS4: cwp-001", "fvcs4-cwp-001"),
          ssh("FVCS4: cwp-002", "fvcs4-cwp-002"),
          ssh("FVCS4: cwp-003", "fvcs4-cwp-003"),
          ssh("FVCS4: cwp-004", "fvcs4-cwp-004"),
          ssh("FVCS4: cwp-005", "fvcs4-cwp-005"),
          ssh("FVCS4: cwp-006", "fvcs4-cwp-006"),
          ssh("FVCS4: app-001", "fvcs4-app-001"),
          ssh("FVCS4: app-002", "fvcs4-app-002"),
          ssh("FVCS4: mgt-001", "fvcs4-mgt-001"),
          ssh("FVCS4: mgt-002", "fvcs4-mgt-002"),
          ssh("FVCS4: mwp-001", "fvcs4-mwp-001"),
          ssh("FVCS4: swp-001", "fvcs4-swp-001"),
        }

        return config
      '';

      # Named with zz- prefix to run after writeBoundary (alphabetical ordering)
      home.sessionVariables = {
        COLORTERM = "truecolor";
      };

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
