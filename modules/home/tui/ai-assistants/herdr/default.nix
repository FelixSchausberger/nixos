{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
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
  };

  config = lib.mkIf config.tui.herdr.enable {
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
    # to match the fleet. The theme leads the file; contributed command
    # bindings follow, separated by a blank line.
    xdg.configFile."herdr/config.toml".text =
      lib.concatStringsSep "\n" (
        ["[theme]" ''name = "catppuccin"'']
        ++ lib.concatMap (key: [""] ++ renderCommandKey key) config.tui.herdr.commandKeys
      )
      + "\n";
  };
}
