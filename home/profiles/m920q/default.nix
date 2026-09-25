{
  lib,
  pkgs,
  config,
  inputs,
  ...
}: {
  # Server home profile: TUI-first dev environment, plus the pieces needed by
  # the on-demand niri projector session (see ./niri.nix). The full desktop app
  # suite is deliberately not imported here.

  # OpenCode 2 beta (opencode2). Enabled here because the shared `homelab`
  # Zellij session and the remote (phone) attach path live on m920q, so the
  # V2 parallel-agent workflow must run on this host. See
  # modules/home/tui/ai-assistants/opencode/v2.nix.
  ai-assistants.opencodeV2.enable = true;

  features = {
    development = {
      enable = true;
      # Rust devshells work out of the box via direnv; no global toolchain needed
      languages = [
        "nix"
        "rust"
      ];
    };
  };

  programs = {
    fish.enable = true;
    starship.enable = true;
    zoxide.enable = true;
    git.enable = true;

    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Opt new sessions into being shareable through the zellij web server
    # (served via Tailscale Serve on this host). The web server itself is the
    # systemd service modules.system.homelab.zellijWeb.
    zellij.settings.web_sharing = "on";
  };
  # opencode scopes sessions by working directory, and its web UI lists only
  # the project matching the server's CWD (default $HOME). Pinning the shared
  # server to the config repo makes TUI (`oc`) and phone-facing web UI show
  # the same sessions.
  systemd.user.services.opencode-web.Service.WorkingDirectory = "/per/etc/nixos";

  home = {
    shellAliases = {
      just = "just --justfile /per/etc/nixos/justfile --working-directory /per/etc/nixos";
    };

    sessionVariables = {
      VITALS_URL = "http://127.0.0.1:8080";
      EDITOR = "hx";
    };

    packages = with pkgs; [
      # System monitoring
      btop
      ncdu
      duf
      iotop
      nethogs
      lsof
      smartmontools

      # Power/CPU monitoring
      linuxPackages.turbostat # Per-CPU frequency and C-state statistics

      # Network tools
      nmap
      dig
      wget
      curl

      # File sharing management
      samba # provides smbclient, smbpasswd, net

      # Remote coding from phone via SSH
      (config.ai-assistants.safeRm.wrap inputs.claude-code-nix.packages.${pkgs.stdenv.hostPlatform.system}.default)

      # Vitals health monitoring CLI
      inputs.vitals.packages.${pkgs.stdenv.hostPlatform.system}.cli
    ];
  };

  # Required by some shared modules

  accounts.calendar.basePath = lib.mkDefault "$HOME/.local/share/calendar";

  # The root vault's .obsidian is a Nextcloud external-storage folder that
  # desktop clients two-way sync, and the running app rewrites its config, so
  # three writers share the same JSON: nix, Obsidian here, and Obsidian on the
  # synced devices. A copy written here bypasses the Nextcloud API and lands as
  # a server-side change underneath the client's copy; the client resolves that
  # by keeping the server version and renaming the local file to a conflicted
  # copy, which silently drops the declared values and repeats on every switch.
  # Nix therefore only seeds settings that are absent and never re-applies them:
  # the declaration is the initial default, Obsidian and the synced devices own
  # the files afterwards. store symlinks are not an option for a writable vault,
  # and only the root vault's initialized .obsidian is seeded - sub-vaults, an
  # unconfigured (empty) .obsidian, and the rest of .obsidian (plugins, hotkeys,
  # graph) stay under Obsidian's own control.
  home.activation.obsidianVaultConfig = let
    declared = {
      "appearance.json" = builtins.toJSON {
        accentColor = "";
        theme = "system";
        cssTheme = "Minimal";
        textFontFamily = "";
        baseFontSize = 16;
        showViewHeader = true;
        showRibbon = false;
      };
      "app.json" = builtins.toJSON {};
      "core-plugins.json" = builtins.toJSON {
        file-explorer = true;
        global-search = true;
        switcher = false;
        graph = false;
        backlink = false;
        canvas = false;
        outgoing-link = false;
        tag-pane = false;
        properties = false;
        page-preview = false;
        daily-notes = false;
        templates = false;
        note-composer = false;
        command-palette = false;
        slash-command = false;
        editor-status = true;
        bookmarks = false;
        markdown-importer = false;
        zk-prefixer = false;
        random-note = false;
        outline = false;
        word-count = false;
        slides = false;
        audio-recorder = false;
        workspaces = false;
        file-recovery = true;
        publish = false;
        sync = false;
        webviewer = false;
        footnotes = false;
        bases = false;
      };
    };
    files =
      lib.mapAttrsToList (name: content: {
        inherit name;
        src = pkgs.writeText name content;
      })
      declared;
  in
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      vault=/per/mnt/data/Obsidian/.obsidian
      if [ -d "$vault" ] && [ -n "$(ls -A "$vault")" ]; then
        ${lib.concatMapStringsSep "\n" (f: ''[ -e "$vault/${f.name}" ] || install -m 0644 ${f.src} "$vault/${f.name}"'') files}
      fi
    '';

  # Convenience links into the data pool (dpool, hosts/m920q/disko.nix) so the
  # canonical locations (/per/mnt/data/...) are reachable under the XDG names.
  # This profile is only imported by m920q, so the paths are safe here.
  # Out-of-store symlinks: HM must not copy the pool into the store.
  # ~/Downloads and ~/Pictures are deliberately local: Downloads are transient
  # and ~/Pictures/Screenshots is written by screenshot tooling (satty, grim).
  home.file = let
    mkDataLink = name: target: {
      "${name}".source = config.lib.file.mkOutOfStoreSymlink target;
    };
  in
    mkDataLink "Documents" "/per/mnt/data/Documents"
    // mkDataLink "Music" "/per/mnt/data/Media/Music"
    // mkDataLink "Videos" "/per/mnt/data/Media";
}
