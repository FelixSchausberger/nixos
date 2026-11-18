{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) user;
  homeDir = "/home/${user}";

  # One [[keybindings.command]] block per contributed binding, rendered from
  # the structured option below. Tools own their own key next to their own
  # config instead of editing this module's config string. The TUIOS loader
  # warns about an unknown key and ignores that entry, so optional fields are
  # omitted rather than emitted empty.
  renderCommandKey = key: let
    fields =
      ["key" "type" "command"]
      ++ lib.optionals (key.description != null) ["description"]
      ++ lib.optionals (key.width != null) ["width"]
      ++ lib.optionals (key.height != null) ["height"];
  in
    ["[[keybindings.command]]"]
    ++ map (field: "${field} = ${builtins.toJSON key.${field}}") fields;

  renderHost = name: host:
    [
      "[hosts.${name}]"
      "addr = ${builtins.toJSON host.addr}"
    ]
    ++ lib.optionals (host.reposRoot != null) ["repos_root = ${builtins.toJSON host.reposRoot}"]
    ++ lib.optionals (host.command != null) ["command = ${builtins.toJSON host.command}"];

  # Vendored `tuios integration install opencode --no-skill` equivalent for
  # the opencodeIntegration option below. The installer cannot run in the
  # user's config root: the config tree is a read-only Home Manager symlink
  # farm, and it writes into plugins/. The derivation runs the installer in a
  # scratch config home and copies out the three files the opencode module
  # ships. V2 discovers the adjacent plugins/tuios-agent-state/ directory and
  # runs its tui.js in the terminal client; the V1 file is kept for V1.
  tuiosOpencodeIntegration = pkgs.runCommand "tuios-opencode-integration-${pkgs.tuios.version}" {} ''
    export HOME=$TMPDIR
    export XDG_CONFIG_HOME=$TMPDIR/.config
    mkdir -p $XDG_CONFIG_HOME/opencode
    printf '{"plugins":[]}' > $XDG_CONFIG_HOME/opencode/cli.json
    ${pkgs.tuios}/bin/tuios integration install opencode --no-skill
    mkdir -p $out
    cp $XDG_CONFIG_HOME/opencode/plugins/tuios-agent-state.js $out/
    cp -r $XDG_CONFIG_HOME/opencode/plugins/tuios-agent-state $out/
  '';

  # TUIOS starts panes from the daemon's environment. SHELL and PATH must
  # resolve like a login shell: agents (opencode2, claude) and the fish
  # functions live in the per-user profile, not in the bare systemd PATH.
  serverEnvironment =
    [
      "HOME=${homeDir}"
      "SHELL=/etc/profiles/per-user/${user}/bin/fish"
      "XDG_CONFIG_HOME=${config.xdg.configHome}"
      "PATH=${homeDir}/.local/bin:/run/wrappers/bin:${homeDir}/.nix-profile/bin:/etc/profiles/per-user/${user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
    ]
    ++ config.tui.tuios.paneEnvironment;
in {
  options.tui.tuios = {
    enable =
      lib.mkEnableOption "TUIOS terminal window manager for AI agents"
      // {
        default = true;
      };

    # TUIOS's only extension point for third-party tools is a custom command
    # keybinding, and a keybinding's target may not exist yet when this module
    # renders the config. Contribute them here so a tool stays self-contained.
    commandKeys = lib.mkOption {
      default = [];
      description = ''
        [[keybindings.command]] entries appended to tuios/config.toml, in the
        order the contributing modules are merged.
      '';
      type = lib.types.listOf (lib.types.submodule {
        options = {
          key = lib.mkOption {
            type = lib.types.str;
            description = "Keybinding string, for example prefix+shift+e.";
          };
          type = lib.mkOption {
            type = lib.types.enum ["scratch" "popup" "pane" "shell" "plugin_action"];
            description = ''
              scratch toggles a floating terminal, popup opens a transient
              overlay, pane opens a split that closes with its command, shell
              runs detached without a window, and plugin_action invokes an
              enabled plugin action.
            '';
          };
          command = lib.mkOption {
            type = lib.types.str;
            description = "Shell line for scratch/popup/pane/shell, or a plugin action id.";
          };
          description = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Label shown in the command palette and keybind list.";
          };
          width = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Popup or scratch width in terminal cells or as a percentage, for example \"95%\".";
          };
          height = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Popup or scratch height in terminal cells or as a percentage.";
          };
        };
      });
    };

    # The config file is read-only under Home Manager, so hosts are declared
    # here instead of with `tuios hosts add`. A host is a machine a client may
    # attach to (the rail and the Inbox include its agents).
    hosts = lib.mkOption {
      default = {};
      description = "Machines this client may reach, rendered as [hosts.NAME] tables.";
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          addr = lib.mkOption {
            type = lib.types.str;
            description = "Anything ssh understands, including an ssh_config alias.";
          };
          reposRoot = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Where the host keeps its checkouts, as the host reads it.";
          };
          command = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "The tuios binary to run on the host instead of the one the link finds.";
          };
        };
      });
    };

    # Boot-persistent agents need the daemon to outlive logouts: linger must
    # be set for this host (m920q gets it from the zellij-web module). Only
    # hosts whose agents must survive a logout or serve remote attaches need
    # the unit; a desktop starts its daemon on first attach.
    server.enable = lib.mkEnableOption ''
      TUIOS daemon as an always-on user service (agent-herd host)
    '';

    # Enables the opencode <-> TUIOS lifecycle integration: turn state, the
    # Inbox, and resumable conversations after a daemon restart. The plugin is
    # client-side; the server entrypoints are stubs.
    opencodeIntegration.enable =
      lib.mkEnableOption "opencode <-> TUIOS lifecycle integration (vendored plugin)"
      // {
        default = true;
      };

    # Extra KEY=VALUE pairs added to the daemon environment and therefore
    # inherited by every pane. Tools contribute their own wiring here instead
    # of editing this module's list.
    paneEnvironment = lib.mkOption {
      default = [];
      description = ''
        KEY=VALUE environment entries appended to the TUIOS daemon
        environment; every spawned pane inherits them.
      '';
      type = lib.types.listOf lib.types.str;
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.tui.tuios.enable {
      home.packages = [pkgs.tuios];

      # Attach entry for remote shells ("mosh m920q -- fish -c hattach") and
      # quick reattaches. Idempotent: the client attaches to the running
      # daemon (the systemd tuios-daemon unit on the agent host) or starts one
      # when no unit exists. TUIOS_PANE_ID is set inside a pane, where
      # attaching the session that holds the pane is refused; the guard turns
      # the mistake into a no-op instead of an error. tattach is the new name;
      # hattach stays for muscle memory and the documented mosh command.
      programs.fish.functions.hattach = {
        description = "Attach to the TUIOS daemon (idempotent client attach)";
        body = ''
          if set -q TUIOS_PANE_ID
            echo "hattach: already inside a TUIOS pane" >&2
            return 0
          end
          command tuios attach $argv
        '';
      };
      programs.fish.functions.tattach = {
        description = "Attach to the TUIOS daemon (idempotent client attach)";
        body = ''
          if set -q TUIOS_PANE_ID
            echo "tattach: already inside a TUIOS pane" >&2
            return 0
          end
          command tuios attach $argv
        '';
      };

      # The config is a read-only store symlink. Hosts and command keys are
      # declared, not added with `tuios hosts add` or the settings page: those
      # write config.toml and would fail. A key that TUIOS does not know is a
      # warning it ignores, and `tuios config apply` reports it.
      xdg.configFile."tuios/config.toml".text =
        lib.concatStringsSep "\n" (
          [
            "# Managed by Home Manager; read-only. Runtime settings edits via"
            "# `tuios set-config` or the settings page cannot persist here."
            ""
          ]
          ++ lib.concatLists (lib.mapAttrsToList renderHost config.tui.tuios.hosts)
          ++ lib.concatMap (key: [""] ++ renderCommandKey key) config.tui.tuios.commandKeys
        )
        + "\n";
    })

    # Upstream's V2 integration writes plugins/tuios-agent-state/ so the
    # terminal client discovers it; the V1 file beside it is kept for V1. Both
    # are client-side reports: a daemon pane's agent reports through its own
    # tty/socket, never the shared server's environment.
    (lib.mkIf config.tui.tuios.opencodeIntegration.enable {
      xdg.configFile."opencode/plugins/tuios-agent-state.js".source = "${tuiosOpencodeIntegration}/tuios-agent-state.js";
      xdg.configFile."opencode/plugins/tuios-agent-state/index.js".source = "${tuiosOpencodeIntegration}/tuios-agent-state/index.js";
      xdg.configFile."opencode/plugins/tuios-agent-state/tui.js".source = "${tuiosOpencodeIntegration}/tuios-agent-state/tui.js";
    })

    (lib.mkIf config.tui.tuios.server.enable {
      # Always-on daemon: remote attach (tuios attach --host over SSH or mosh)
      # needs a live socket without a desktop client attached. Restart
      # semantics match upstream's generated unit: layout and directories are
      # restored, pane processes are NOT, and agent conversations resume
      # through the lifecycle integration's recorded session ids. A deploy
      # that restarts this unit therefore follows the reboot checklist (flush
      # agents first). KillMode=process lets programs started with nohup in a
      # pane (or a live-upgrade keeper) outlive the unit stop.
      systemd.user.services.tuios-daemon = {
        Unit = {
          Description = "TUIOS daemon";
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.tuios}/bin/tuios daemon --service";
          Environment = serverEnvironment;
          WorkingDirectory = homeDir;
          KillMode = "process";
          Restart = "on-failure";
          RestartSec = 2;
          UnsetEnvironment = ["DISPLAY" "WAYLAND_DISPLAY" "XAUTHORITY"];
        };
        Install = {
          WantedBy = ["default.target"];
        };
      };
    })
  ];
}
