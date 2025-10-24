{
  pkgs,
  lib,
  osConfig,
  config,
  inputs,
  ...
}: {
  # Install ghost plugin to Zellij plugins directory
  home.file.".config/zellij/plugins/ghost.wasm".source = "${inputs.self.packages.${pkgs.system}.zellij-ghost}/share/zellij/plugins/ghost.wasm";

  programs.zellij = {
    enable = true;

    settings =
      {
        theme = "catppuccin-mocha";
        default_shell = "fish";
        default_cwd = "/home/schausberger";

        # UI settings
        pane_frames = false;
        simplified_ui = true;
        default_layout = "compact";

        # Mouse support
        mouse_mode = true;
        copy_on_select = true;

        # Session settings
        session_serialization = false;
        pane_viewport_serialization = false;

        scrollback_editor = "${pkgs.helix}/bin/hx";
        auto_layout = true;
      }
      # WSL-specific clipboard integration: only use clip.exe on WSL hosts
      # Native Linux hosts use system clipboard by default
      // lib.optionalAttrs (osConfig.modules.system.wsl-integration.enable or false) {
        copy_command = "clip.exe";
      }
      // {
        # Load plugins at startup
        # Note: zjstatus is loaded automatically when referenced in layouts
      };

    # Keybindings for minimal but intuitive workflow using extraConfig
    # This uses KDL format which is zellij's current native configuration format
    extraConfig = ''
      ui {
        pane_frames {
          rounded_corners true
        }
      }

      plugins {
        compact-bar location="zellij:compact-bar" {
          tooltip "F1"
        }

        harpoon location="https://github.com/Nacho114/harpoon/releases/latest/download/harpoon.wasm"
        forgot location="https://github.com/karimould/zellij-forgot/releases/latest/download/zellij_forgot.wasm"
        ghost location="file:${config.home.homeDirectory}/.config/zellij/plugins/ghost.wasm"
      }

      keybinds {
        shared {
          // Copy to clipboard (Zellij action)
          bind "Ctrl Shift c" { Copy; }
          // Note: Ctrl+Shift+V is not bound - terminal handles paste automatically
        }

        normal {
          // Quick plugin access as floating popups
          bind "Ctrl f" { LaunchOrFocusPlugin "forgot" { floating true; }; }
          bind "Ctrl g" { LaunchOrFocusPlugin "ghost" { floating true; shell "fish"; shell_flag "-c"; }; }
          bind "Ctrl h" { LaunchOrFocusPlugin "harpoon" { floating true; }; }

          // Quick access to tools in dedicated panes
          bind "Alt y" { NewPane "Down"; Run "yazi"; }
          bind "Alt g" { NewPane "Right"; Run "lazygit"; }
          bind "Alt j" { NewPane "Right"; Run "lazyjj"; }
          bind "Alt e" { NewPane "Down"; Run "hx"; }
        }
      }
    '';
  };
}
