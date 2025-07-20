{pkgs, ...}: {
  programs.zellij = {
    enable = true;

    settings = {
      # Theme matching Catppuccin Mocha (consistent with Zed)
      theme = "catppuccin-mocha";

      # Default shell
      default_shell = "fish";

      # UI settings
      pane_frames = false;
      simplified_ui = true;
      default_layout = "compact";

      # Mouse support
      mouse_mode = true;
      copy_on_select = false;

      # Session settings
      session_serialization = false;
      pane_viewport_serialization = false;

      # Scrollback
      scrollback_editor = "${pkgs.helix}/bin/hx";

      # Auto layout
      auto_layout = true;

      # Plugin management
      plugins = {
        # Status bar with minimal design
        zjstatus = {
          path = "https://github.com/dj95/zjstatus/releases/latest/download/zjstatus.wasm";
        };

        # Git branch management
        git-branch = {
          path = "https://github.com/dj95/zj-git-branch/releases/latest/download/zj-git-branch.wasm";
        };

        # Quick keybinding hints
        forgot = {
          path = "https://github.com/karimould/zellij-forgot/releases/latest/download/zellij_forgot.wasm";
        };

        # Harpoon-like navigation
        harpoon = {
          path = "https://github.com/Nacho114/harpoon/releases/latest/download/harpoon.wasm";
        };
      };

      # Keybindings for minimal but intuitive workflow
      keybinds = {
        normal = {
          # Quick plugin access
          "Ctrl f" = {LaunchPlugin = {location = "file:forgot";};};
          "Ctrl g" = {LaunchPlugin = {location = "file:git-branch";};};
          "Ctrl h" = {LaunchPlugin = {location = "file:harpoon";};};
        };
      };
    };
  };

  # Create custom layouts directory
  home.file.".config/zellij/layouts/dev.kdl".text = ''
    layout {
        default_tab_template {
            children
            pane size=1 borderless=true {
                plugin location="zjstatus" {
                    format_left   "#[fg=#89B4FA,bold]{session} {mode}"
                    format_center ""
                    format_right  "#[fg=#89B4FA]{datetime}"
                    format_space  ""

                    hide_frame_for_single_pane "false"

                    mode_normal        "#[bg=#89B4FA] "
                    mode_locked        "#[bg=#89B4FA] LOCKED "
                    mode_resize        "#[bg=#89B4FA] RESIZE "
                    mode_pane          "#[bg=#89B4FA] PANE "
                    mode_tab           "#[bg=#89B4FA] TAB "
                    mode_scroll        "#[bg=#89B4FA] SCROLL "
                    mode_enter_search  "#[bg=#89B4FA] ENT-SEARCH "
                    mode_search        "#[bg=#89B4FA] SEARCHMODE "
                    mode_rename_tab    "#[bg=#89B4FA] RENAME "
                    mode_rename_pane   "#[bg=#89B4FA] RENAME-PANE "
                    mode_session       "#[bg=#89B4FA] SESSION "
                    mode_move          "#[bg=#89B4FA] MOVE "
                    mode_prompt        "#[bg=#89B4FA] PROMPT "
                    mode_tmux          "#[bg=#89B4FA] TMUX "

                    datetime        "#[fg=#6C7086,bold] {format} "
                    datetime_format "%A, %d %b %Y %H:%M"
                    datetime_timezone "Europe/Vienna"
                }
            }
        }

        tab name="dev" focus=true {
            pane split_direction="vertical" {
                pane name="editor" focus=true
                pane split_direction="horizontal" {
                    pane name="terminal" size="70%"
                    pane name="git" size="30%"
                }
            }
        }
    }
  '';
}
