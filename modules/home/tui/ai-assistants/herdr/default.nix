{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib) user;
  homeDir = "/home/${user}";

  # One [[keys.command]] block per contributed binding, rendered from the
  # structured option below. Tools own their own key next to their own config
  # instead of editing this module's config string. Optional fields are omitted
  # rather than emitted empty: herdr rejects an unknown or blank value and falls
  # back to a safe default with a startup warning.
  renderCommandKey = key: let
    fields =
      ["key" "type" "command"]
      ++ lib.optionals (key.description != null) ["description"]
      ++ lib.optionals (key.width != null) ["width"]
      ++ lib.optionals (key.height != null) ["height"];
  in
    ["[[keys.command]]"]
    ++ map (field: "${field} = ${builtins.toJSON key.${field}}") fields;

  # Vendored `herdr integration install opencode` equivalent for the
  # opencodeIntegration option below. The installer cannot run in the user's
  # config root: it rewrites cli.json, which the opencode module renders as a
  # read-only store symlink (herdr itself refuses with "config has multiple
  # hard links"; verified 2026-10-30). The derivation runs the same installer
  # inside the build sandbox against a scratch config home seeded with a
  # cli.json, which drives it down the V2 path, and copies out exactly the two
  # files the opencode module then ships. Files update together with the herdr
  # derivation by construction; a herdr integration protocol that drifts ahead
  # of its nixpkgs pin surfaces as missing state, not a broken build.
  herdrOpencodeIntegration = pkgs.runCommand "herdr-opencode-integration-${pkgs.herdr.version}" {} ''
    export HOME=$TMPDIR
    mkdir -p $TMPDIR/.config/opencode
    # A cli.json in the scratch config home is what forces the installer's V2
    # path (without one it renders the V1 tui.jsonc registration).
    printf '{"plugins":[]}' > $TMPDIR/.config/opencode/cli.json
    ${pkgs.herdr}/bin/herdr integration install opencode
    mkdir -p $out/herdr-opencode
    cp $TMPDIR/.config/opencode/herdr-tui-session.js $out/
    cp $TMPDIR/.config/opencode/herdr-opencode/tui.js $out/herdr-opencode/
  '';

  # herdr detects the default shell from SHELL and spawns panes with it;
  # agents (opencode2, claude) must resolve like a login shell.
  serverEnvironment = [
    "SHELL=/etc/profiles/per-user/${user}/bin/fish"
    "PATH=${homeDir}/.local/bin:/run/wrappers/bin:${homeDir}/.nix-profile/bin:/etc/profiles/per-user/${user}/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin"
  ];
in {
  options.tui.herdr = {
    enable =
      lib.mkEnableOption "herdr terminal multiplexer for AI agents"
      // {
        default = true;
      };

    # herdr's only extension point for third-party tools without a plugin is a
    # custom command keybinding, and a keybinding's target may not exist yet when
    # this module renders the config. Contribute them here so a tool stays
    # self-contained.
    commandKeys = lib.mkOption {
      default = [];
      description = ''
        [[keys.command]] entries appended to herdr/config.toml, in the order the
        contributing modules are merged.
      '';
      type = lib.types.listOf (lib.types.submodule {
        options = {
          key = lib.mkOption {
            type = lib.types.str;
            description = "Keybinding string, for example prefix+shift+e.";
          };
          type = lib.mkOption {
            type = lib.types.enum ["popup" "pane" "shell" "plugin_action"];
            description = ''
              popup and pane run a shell command and close when it exits,
              shell runs detached, plugin_action invokes an installed plugin.
            '';
          };
          command = lib.mkOption {
            type = lib.types.str;
            description = "Command line for a shell/popup/pane binding, or a plugin action id.";
          };
          description = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Label shown in the keybind help panel (prefix+?).";
          };
          width = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Popup width in terminal cells or as a percentage, for example \"95%\".";
          };
          height = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Popup height in terminal cells or as a percentage.";
          };
        };
      });
    };

    # Boot-persistent agents need the session server to outlive logouts:
    # linger must be set for this host (m920q gets it already from the
    # zellij-web module's users.users.${user}.linger). Per host: agents live
    # in the herdr server only where the phone/fleet workflows need them.
    server.enable = lib.mkEnableOption ''
      herdr headless server as an always-on user service (phone bridge host)
    '';

    # Enables the opencode <-> herdr lifecycle integration. Registration
    # happens in the opencode module (v2.nix), which appends herdr's plugin
    # directory entry to cli.json when this is on.
    opencodeIntegration.enable =
      lib.mkEnableOption "opencode <-> herdr lifecycle integration (vendored plugin)";
  };

  config = lib.mkMerge [
    (lib.mkIf config.tui.herdr.enable {
      home.packages = [pkgs.herdr];

      # herdr's plugin registry is imperative state (plugins.json) keyed by the
      # linked source path, so it cannot be a read-only Home Manager file. Link
      # the TTT editor plugin out of the ttt flake input at activation; relinking
      # is idempotent and repoints the plugin after a ttt bump. The herdr binary
      # is called by absolute path because activation runs before the new
      # profile is on PATH; XDG_CONFIG_HOME is pinned so the link lands in the
      # same config root as xdg.configFile below.
      home.activation.linkTttHerdrPlugin = lib.hm.dag.entryAfter ["writeBoundary"] ''
        XDG_CONFIG_HOME=${config.xdg.configHome} \
          ${pkgs.herdr}/bin/herdr plugin link ${inputs.ttt}/herdr-plugin \
          >/dev/null 2>&1 || true
      '';

      # herdr ships a built-in catppuccin theme, so it needs no generated palette
      # to match the fleet. The file is a read-only store symlink, and herdr
      # writes `onboarding = false` back to it when its first-run setup finishes:
      # the write fails with "failed to save onboarding setting: Read-only file
      # system" and the setup prompt (including its integration-install offer)
      # returns on every launch. Declaring the value skips that setup entirely.
      # Bare key/value pairs must precede the first table header in TOML, so
      # onboarding leads the file, then tables, then the contributed command
      # bindings.
      #
      # update.version_check pins the updater: nixpkgs owns the binary, and
      # `herdr update` would install a shadowing copy into ~/.local/bin, which
      # comes first on PATH (the zellij-web service documents the same order).
      # A herdr bump lands through the flake, not from inside the TUI.
      xdg.configFile."herdr/config.toml".text =
        lib.concatStringsSep "\n" (
          [
            "onboarding = false"
            ""
            "[update]"
            "version_check = false"
            ""
            "[theme]"
            ''name = "catppuccin"''
          ]
          ++ lib.concatMap (key: [""] ++ renderCommandKey key) config.tui.herdr.commandKeys
        )
        + "\n";
    })

    # Upstream registers the V2 integration as the directory "./herdr-opencode"
    # in cli.json (verified against `herdr integration install opencode` on a
    # scratch config home); the cliConfig side is in the opencode v2 module,
    # which appends the entry when the option is on. The server-side
    # auto-discovered entrypoint (plugins/herdr-agent-state.js, the V1
    # headless-reporter path) is deliberately NOT vendored: the phone-facing
    # shared server must not run a second state reporter that competes with
    # the pane-local TUI reporter (upstream docs: restart server and TUIs so
    # "the old server reporter cannot overwrite pane-local state").
    (lib.mkIf config.tui.herdr.opencodeIntegration.enable {
      xdg.configFile."opencode/herdr-tui-session.js".source = "${herdrOpencodeIntegration}/herdr-tui-session.js";
      xdg.configFile."opencode/herdr-opencode/tui.js".source = "${herdrOpencodeIntegration}/herdr-opencode/tui.js";
    })

    (lib.mkIf config.tui.herdr.server.enable {
      # Always-on headless server: remote attend (herdr attach, the session
      # picker on a phone client, a later PWA bridge) needs a live socket
      # without a desktop client attached.
      # Restart semantics are reboot-like, the same upstream evidence class
      # as `herdr server stop`: layout and directories are restored, pane
      # processes are NOT, and agent conversations resume through the
      # lifecycle integration's recorded session ids. A comin deploy that
      # changes this unit therefore follows the reboot checklist (flush
      # agents first).
      systemd.user.services.herdr-server = {
        Unit = {
          Description = "herdr headless session server";
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.herdr}/bin/herdr server";
          # Crash restarts bring layout back and resumable conversations with
          # it; a clean `herdr server stop` exits 0 and does not restart.
          Restart = "on-failure";
          RestartSec = "3";
          Environment = serverEnvironment;
        };
        Install = {
          WantedBy = ["default.target"];
        };
      };
    })
  ];
}
