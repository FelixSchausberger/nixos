{
  pkgs,
  inputs,
  lib,
  ...
}: let
  inherit (inputs.self.lib) defaults;
  catppuccin = inputs.self.lib.catppuccinColors.mocha;
  defaultLayout = ''
    layout {
      default_tab_template {
        children
        pane size=1 borderless=true {
          plugin location="zjstatus" {
            format_left   "{mode}"
            format_center "{tabs}"
            format_right  "{pipe_zjstatus_hints} {datetime}"
            format_space  ""

            pipe_zjstatus_hints_format "{output}"

            border_enabled "false"
            hide_frame_for_single_pane "false"

            mode_normal      "#[bg=${catppuccin.green},fg=${catppuccin.base},bold] NORMAL "
            mode_locked      "#[bg=${catppuccin.surface0},fg=${catppuccin.text}] LOCKED "
            mode_tab         "#[bg=${catppuccin.blue},fg=${catppuccin.base},bold] TAB "
            mode_pane        "#[bg=${catppuccin.mauve},fg=${catppuccin.base},bold] PANE "
            mode_resize      "#[bg=${catppuccin.peach},fg=${catppuccin.base},bold] RESIZE "
            mode_move        "#[bg=${catppuccin.yellow},fg=${catppuccin.base},bold] MOVE "
            mode_scroll      "#[bg=${catppuccin.teal},fg=${catppuccin.base},bold] SCROLL "
            mode_search      "#[bg=${catppuccin.red},fg=${catppuccin.base},bold] SEARCH "
            mode_session     "#[bg=${catppuccin.pink},fg=${catppuccin.base},bold] SESSION "
            mode_entersearch "#[bg=${catppuccin.red},fg=${catppuccin.base},bold] ENTERSEARCH "

            tab_normal      "#[fg=${catppuccin.overlay1}] {name} "
            tab_active      "#[fg=${catppuccin.text},bold] {name} "
            tab_separator   "#[fg=${catppuccin.surface1}]|"

            datetime         "#[fg=${catppuccin.subtext0}] {format}"
            datetime_format  "%H:%M"
            datetime_timezone "Europe/Vienna"
          }
        }
      }
    }
  '';

  rustLayout = ''
    layout {
      pane split_direction="vertical" {
        // Editor on top, cargo watch terminal on the bottom.
        // Launch with `zellij --layout rust` from a Rust project directory.
        pane command="hx"
        pane command="cargo" {
          args "watch"
        }
      }
    }
  '';
in {
  home.activation.writeZellijPermissions = lib.hm.dag.entryAfter ["writeBoundary"] ''
    permissions_file="$HOME/.cache/zellij/permissions.kdl"
    mkdir -p "$(dirname "$permissions_file")"
    $DRY_RUN_CMD cat > "$permissions_file" << 'PERMISSIONS_EOF'
    "${defaults.paths.homeDir}/.config/zellij/plugins/zjstatus.wasm" {
        RunCommands
        ChangeApplicationState
        ReadApplicationState
    }
    "${defaults.paths.homeDir}/.config/zellij/plugins/zjstatus-hints.wasm" {
        MessageAndLaunchOtherPlugins
        ChangeApplicationState
        ReadCliPipes
        ReadApplicationState
    }
    "${defaults.paths.homeDir}/.config/zellij/plugins/harpoon.wasm" {
        ReadApplicationState
        ChangeApplicationState
    }
    "${defaults.paths.homeDir}/.config/zellij/plugins/forgot.wasm" {
        ReadApplicationState
        ChangeApplicationState
    }
    "${defaults.paths.homeDir}/.config/zellij/plugins/attention.wasm" {
        MessageAndLaunchOtherPlugins
        ChangeApplicationState
        ReadCliPipes
        ReadApplicationState
    }
    PERMISSIONS_EOF

    # Clean up stale session metadata older than 7 days to prevent "About Zellij" pane popup
    session_dir="$HOME/.cache/zellij/contract_version_1/session_info"
    if [ -d "$session_dir" ]; then
      find "$session_dir" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true
    fi
  '';
  programs.zellij = {
    enable = true;

    layouts = {
      default = defaultLayout;
      rust = rustLayout;
    };

    plugins = [
      pkgs.zjstatus
      pkgs."zjstatus-hints"
      pkgs.zellij-attention
      pkgs.harpoon-plugin
      pkgs.zellij-forgot
    ];

    settings = {
      theme = "catppuccin-mocha";
      default_shell = "fish";
      default_cwd = defaults.paths.homeDir;
      default_mode = "Locked";

      # UI settings
      pane_frames = false;
      simplified_ui = true;
      default_layout = "default";
      show_startup_tips = false;

      # Mouse support
      mouse_mode = true;
      copy_on_select = true; # Automatically copy selected text via OSC 52

      # Session settings
      session_serialization = true;
      disable_session_metadata = false;

      scrollback_editor = "${pkgs.helix}/bin/hx";
      auto_layout = true;

      # Home Manager aliases every plugin, but only headless pipe consumers
      # should start eagerly. UI plugins remain layout/on-demand driven.
      load_plugins = lib.mkForce {
        _children = [
          {"zjstatus-hints" = [];}
          {attention = [];}
        ];
      };
    };

    # Unlock-first keybinding preset with Colemak-DH navigation
    # Prevents conflicts with Claude Code shortcuts (Ctrl+T, Ctrl+O, etc.)
    #
    # Workflow:
    #   - Normal/Locked mode: Claude Code shortcuts work without interference
    #   - Press Ctrl+Space to unlock and access Zellij modes
    #   - Press mode key (t/p/s/etc) then action key
    #   - Esc returns to locked mode
    #
    # Navigation uses Colemak-DH layout (neio)
    # This uses KDL format which is zellij's current native configuration format
    extraConfig = ''
      ui {
        pane_frames {
          rounded_corners true
        }
      }

      keybinds clear-defaults=true {
        // Locked mode (default): Claude Code shortcuts work unimpeded
        // Copy/Paste workflow for Windows Terminal:
        //   - Select text with mouse
        //   - Press Ctrl+Shift+C (Windows Terminal native) to copy
        //   - Press Ctrl+Shift+V (Windows Terminal native) to paste
        // This bypasses clip.exe and handles UTF-8 correctly
        locked {
          bind "Ctrl Space" { SwitchToMode "Normal"; }

          // Quick plugin access as floating popups (work in locked mode)
          bind "Alt w" { LaunchOrFocusPlugin "forgot" { floating true; }; }
          bind "Alt r" { LaunchOrFocusPlugin "harpoon" { floating true; }; }

          // Floating scratchpad shell for quick commands
          bind "Alt x" { Run "fish" { floating true; x "12%"; y "12%"; width "75%"; height "75%"; }; }

          // Quick access to tools in dedicated panes
          bind "Alt y" { NewPane "Down"; Run "yazi"; }
          bind "Alt g" { NewPane "Right"; Run "lazygit"; }
          bind "Alt z" { NewPane "Right"; Run "lazyjj"; }
          bind "Alt e" { NewPane "Down"; Run "hx"; }
        }

        // Normal mode: Gateway to other modes
        normal {
          bind "Esc" { SwitchToMode "Locked"; }
          bind "Alt Space" { SwitchToMode "Locked"; }

          // Mode switches
          bind "t" { SwitchToMode "Tab"; }
          bind "p" { SwitchToMode "Pane"; }
          bind "r" { SwitchToMode "Resize"; }
          bind "s" { SwitchToMode "Scroll"; }
          bind "m" { SwitchToMode "Move"; }
          bind "q" { Quit; }

          // Quick plugin access (also work in normal mode)
          bind "Alt w" { LaunchOrFocusPlugin "forgot" { floating true; }; }
          bind "Alt r" { LaunchOrFocusPlugin "harpoon" { floating true; }; }
          bind "Alt x" { Run "fish" { floating true; x "12%"; y "12%"; width "75%"; height "75%"; }; }
          bind "Alt y" { NewPane "Down"; Run "yazi"; }
          bind "Alt g" { NewPane "Right"; Run "lazygit"; }
          bind "Alt z" { NewPane "Right"; Run "lazyjj"; }
          bind "Alt e" { NewPane "Down"; Run "hx"; }
        }

        // Tab mode: Manage tabs
        tab {
          bind "Esc" { SwitchToMode "Locked"; }
          bind "t" { NewTab; SwitchToMode "Locked"; }
          bind "x" { CloseTab; SwitchToMode "Locked"; }
          bind "n" { GoToNextTab; }
          bind "p" { GoToPreviousTab; }
          bind "1" { GoToTab 1; SwitchToMode "Locked"; }
          bind "2" { GoToTab 2; SwitchToMode "Locked"; }
          bind "3" { GoToTab 3; SwitchToMode "Locked"; }
          bind "4" { GoToTab 4; SwitchToMode "Locked"; }
          bind "5" { GoToTab 5; SwitchToMode "Locked"; }
          bind "6" { GoToTab 6; SwitchToMode "Locked"; }
          bind "7" { GoToTab 7; SwitchToMode "Locked"; }
          bind "8" { GoToTab 8; SwitchToMode "Locked"; }
          bind "9" { GoToTab 9; SwitchToMode "Locked"; }
          bind "Tab" { ToggleTab; }
          bind "r" {
            SwitchToMode "RenameTab"
            TabNameInput 0
          }
        }

        renametab {
          bind "Esc" {
            UndoRenameTab
            SwitchToMode "tab"
          }
        }

        // Pane mode: Manage panes with Colemak-DH navigation (neio)
        pane {
          bind "Esc" { SwitchToMode "Locked"; }
          bind "n" { MoveFocus "Left"; }
          bind "e" { MoveFocus "Down"; }
          bind "i" { MoveFocus "Up"; }
          bind "o" { MoveFocus "Right"; }
          bind "s" { NewPane "Down"; SwitchToMode "Locked"; }
          bind "v" { NewPane "Right"; SwitchToMode "Locked"; }
          bind "x" { CloseFocus; SwitchToMode "Locked"; }
          bind "f" { ToggleFocusFullscreen; SwitchToMode "Locked"; }
          bind "z" { TogglePaneFrames; SwitchToMode "Locked"; }
          bind "w" { ToggleFloatingPanes; SwitchToMode "Locked"; }
        }

        // Resize mode: Resize panes with Colemak-DH navigation (NEIO)
        resize {
          bind "Esc" { SwitchToMode "Locked"; }
          bind "n" { Resize "Increase Left"; }
          bind "e" { Resize "Increase Down"; }
          bind "i" { Resize "Increase Up"; }
          bind "o" { Resize "Increase Right"; }
          bind "N" { Resize "Decrease Left"; }
          bind "E" { Resize "Decrease Down"; }
          bind "I" { Resize "Decrease Up"; }
          bind "O" { Resize "Decrease Right"; }
          bind "=" { Resize "Increase"; }
          bind "-" { Resize "Decrease"; }
        }

        // Move mode: Move panes with Colemak-DH navigation (neio)
        move {
          bind "Esc" { SwitchToMode "Locked"; }
          bind "n" { MovePane "Left"; }
          bind "e" { MovePane "Down"; }
          bind "i" { MovePane "Up"; }
          bind "o" { MovePane "Right"; }
          bind "t" { MovePane; }
        }

        // Scroll mode: Scroll with Colemak-DH navigation (e/i for down/up)
        scroll {
          bind "Esc" { SwitchToMode "Locked"; }
          bind "e" { ScrollDown; }
          bind "i" { ScrollUp; }
          bind "Ctrl f" { PageScrollDown; }
          bind "Ctrl b" { PageScrollUp; }
          bind "d" { HalfPageScrollDown; }
          bind "u" { HalfPageScrollUp; }
          bind "s" { SwitchToMode "EnterSearch"; SearchInput 0; }
        }

        // Search mode
        search {
          bind "Esc" { SwitchToMode "Locked"; }
          bind "e" { ScrollDown; }
          bind "i" { ScrollUp; }
          bind "Ctrl f" { PageScrollDown; }
          bind "Ctrl b" { PageScrollUp; }
          bind "d" { HalfPageScrollDown; }
          bind "u" { HalfPageScrollUp; }
          bind "n" { Search "down"; }
          bind "p" { Search "up"; }
          bind "c" { SearchToggleOption "CaseSensitivity"; }
          bind "w" { SearchToggleOption "Wrap"; }
          bind "o" { SearchToggleOption "WholeWord"; }
        }

        // Enter search mode
        entersearch {
          bind "Esc" { SwitchToMode "Locked"; }
          bind "Enter" { SwitchToMode "Search"; }
        }

        // Session mode
        session {
          bind "Esc" { SwitchToMode "Locked"; }
          bind "d" { Detach; }
          bind "w" {
            LaunchOrFocusPlugin "session-manager" {
              floating true
              move_to_focused_tab true
            }
            SwitchToMode "Locked"
          }
        }

        // Shared bindings across all modes
        shared_except "locked" {
          bind "Ctrl c" { SwitchToMode "Locked"; }
        }
      }
    '';
  };
}
