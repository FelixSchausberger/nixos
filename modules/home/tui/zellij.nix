{pkgs, ...}: {
  programs.zellij = {
    enable = true;

    settings = {
      theme = "catppuccin-mocha";
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

      scrollback_editor = "${pkgs.helix}/bin/hx";
      auto_layout = true;

      plugins = {
        # Status bar with minimal design - using flake-based package
        zjstatus = {
          path = "${pkgs.zjstatus}/bin/zjstatus.wasm";
        };

        # Compact bar with F1 toggle for keybinding hints
        compact-bar = {
          path = "zellij:compact-bar";
        };

        # Additional plugins via URLs (until flakes are available)
        harpoon = {
          path = "https://github.com/Nacho114/harpoon/releases/latest/download/harpoon.wasm";
        };

        forgot = {
          path = "https://github.com/karimould/zellij-forgot/releases/latest/download/zellij_forgot.wasm";
        };
      };

      # Load plugins at startup
      # Note: zjstatus is loaded automatically when referenced in layouts
    };

    # Keybindings for minimal but intuitive workflow using extraConfig
    # This uses KDL format which is zellij's current native configuration format
    extraConfig = ''
      plugins {
        compact-bar location="zellij:compact-bar" {
          tooltip "F1"
        }
      }

      keybinds {
        normal {
          // Quick plugin access
          bind "Ctrl f" { LaunchPlugin "file:forgot"; }
          bind "Ctrl h" { LaunchPlugin "file:harpoon"; }

          // Ghost floating terminal with Fish completion
          bind "Alt t" { LaunchOrFocusPlugin "file:ghost" { floating true; shell "fish"; shell_flag "-ic"; }; }

          // Quick access to tools in dedicated panes - Fixed syntax
          bind "Alt y" { NewPane "Down" "yazi"; }
          bind "Alt l" { NewPane "Right" "lazygit"; }
          bind "Alt e" { NewPane "Down" "hx"; }
        }
      }
    '';
  };

  # Create enhanced development layout
  home.file.".config/zellij/layouts/dev.kdl".text = ''
    layout {
        default_tab_template {
            children
            pane size=1 borderless=true {
                plugin location="zjstatus" {
                    format_left "{mode}#[bg=#181926] {tabs}"
                    format_center ""
                    format_right "{swap_layout}#[bg=#181926,fg=#494d64] Zellij: #[bg=#181926,fg=#494d64]{session}"
                    format_space "#[bg=#181926]"
                    format_hide_on_overlength "true"
                    format_precedence "crl"

                    border_enabled "false"
                    border_char "─"
                    border_format "#[fg=#6C7086]{char}"
                    border_position "top"

                    hide_frame_for_single_pane "true"

                    mode_normal "#[bg=#a6da95,fg=#181926,bold] NORMAL#[bg=#181926,fg=#a6da95]"
                    mode_locked "#[bg=#6e738d,fg=#181926,bold] LOCKED #[bg=#181926,fg=#6e738d]"
                    mode_resize "#[bg=#8aadf4,fg=#181926,bold] RESIZE#[bg=#181926,fg=#8aadf4]"
                    mode_pane "#[bg=#8aadf4,fg=#181926,bold] PANE#[bg=#181926,fg=#8aadf4]"
                    mode_tab "#[bg=#8aadf4,fg=#181926,bold] TAB#[bg=#181926,fg=#8aadf4]"
                    mode_scroll "#[bg=#8aadf4,fg=#181926,bold] SCROLL#[bg=#181926,fg=#8aadf4]"
                    mode_enter_search "#[bg=#8aadf4,fg=#181926,bold] ENT-SEARCH#[bg=#181926,fg=#8aadf4]"
                    mode_search "#[bg=#8aadf4,fg=#181926,bold] SEARCH#[bg=#181926,fg=#8aadf4]"
                    mode_rename_tab "#[bg=#8aadf4,fg=#181926,bold] RENAME TAB#[bg=#181926,fg=#8aadf4]"
                    mode_rename_pane "#[bg=#8aadf4,fg=#181926,bold] RENAME PANE#[bg=#181926,fg=#8aadf4]"
                    mode_session "#[bg=#8aadf4,fg=#181926,bold] SESSION#[bg=#181926,fg=#8aadf4]"
                    mode_move "#[bg=#8aadf4,fg=#181926,bold] MOVE#[bg=#181926,fg=#8aadf4]"
                    mode_prompt "#[bg=#8aadf4,fg=#181926,bold] PROMPT#[bg=#181926,fg=#8aadf4]"
                    mode_tmux "#[bg=#ffc387,fg=#181926,bold] TMUX#[bg=#181926,fg=#ffc387]"

                    tab_normal "#[fg=#6e738d,bg=#181926] {name} "
                    tab_active "#[fg=#cad3f5,bg=#181926,bold,italic] {name} "

                    swap_layout_icon ""
                }
            }
        }

        tab name="main" focus=true {
            pane split_direction="vertical" {
                pane name="editor" focus=true size="60%" {
                    command "hx"
                }
                pane split_direction="horizontal" size="40%" {
                    pane name="terminal" size="70%"
                    pane name="git" size="30%" {
                        command "lazygit"
                    }
                }
            }
        }

        tab name="files" {
            pane name="file-manager" {
                command "yazi"
            }
        }

        tab name="monitor" {
            pane split_direction="vertical" {
                pane name="system" size="50%" {
                    command "btop"
                }
                pane name="logs" size="50%" {
                    command "journalctl"
                    args "-f"
                }
            }
        }
    }
  '';
}
