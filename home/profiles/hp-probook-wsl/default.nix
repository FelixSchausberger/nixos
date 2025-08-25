{lib, ...}: let
  # GlazeWM Configuration Generator
  glazeWMConfig = {
    # Monitor and workspace configuration
    monitorCount = 3;
    workspacesPerMonitor = 9;
    monitorLabels = ["a" "b" "c"]; # Extend this list for more monitors

    # Helper function to generate workspaces for all monitors
    generateWorkspaces = monitors: workspaceCount:
      lib.concatMap (
        monitorIndex: let
          monitorLabel = lib.elemAt monitors monitorIndex;
        in
          map (wsNum: {
            name = "${monitorLabel}${toString wsNum}";
            display_name = toString wsNum;
            bind_to_monitor = monitorIndex;
          }) (lib.range 1 workspaceCount)
      ) (lib.range 0 (lib.length monitors - 1));

    # Helper function to generate keybindings for workspace switching
    generateWorkspaceKeybindings = monitors: workspaceCount: action:
      map (wsNum: {
        commands = [
          "shell-exec --hide-window node \"%userprofile%/.glzr/glazewm/scripts/workspaceAction.js\" ${action} ${
            lib.concatStringsSep " " (map (label: "${label}${toString wsNum}") monitors)
          }"
        ];
        bindings = [
          "alt+${
            if action == "move"
            then "shift+"
            else ""
          }${toString wsNum}"
        ];
      }) (lib.range 1 workspaceCount);

    # Standard window rules - extracted to reduce repetition
    standardWindowRules = [
      {
        commands = ["ignore"];
        match = [
          {window_process = {equals = "zebar";};}
          {
            window_title = {regex = "[Pp]icture.in.[Pp]icture";};
            window_class = {regex = "Chrome_WidgetWin_1|MozillaDialogClass";};
          }
          {
            window_process = {equals = "PowerToys";};
            window_class = {regex = "HwndWrapper\\[PowerToys\\.PowerAccent.*?\\]";};
          }
          {
            window_process = {equals = "PowerToys";};
            window_title = {regex = ".*? - Peek";};
          }
          {
            window_process = {equals = "Lively";};
            window_class = {regex = "HwndWrapper";};
          }
          {
            window_process = {equals = "EXCEL";};
            window_class = {not_regex = "XLMAIN";};
          }
          {
            window_process = {equals = "WINWORD";};
            window_class = {not_regex = "OpusApp";};
          }
          {
            window_process = {equals = "POWERPNT";};
            window_class = {not_regex = "PPTFrameClass";};
          }
          {
            window_process = {regex = ".*Terminal.*";};
            window_class = {equals = "CASCADIA_HOSTING_WINDOW_CLASS";};
          }
        ];
      }
      {
        commands = ["set-floating"];
        match = [
          {window_title = {equals = "Command Palette";};}
        ];
      }
    ];

    # Standard keybindings - movement, resize, etc.
    standardKeybindings = [
      # Focus movement
      {
        commands = ["focus --direction left"];
        bindings = ["alt+h" "alt+left"];
      }
      {
        commands = ["focus --direction right"];
        bindings = ["alt+l" "alt+right"];
      }
      {
        commands = ["focus --direction up"];
        bindings = ["alt+k" "alt+up"];
      }
      {
        commands = ["focus --direction down"];
        bindings = ["alt+j" "alt+down"];
      }

      # Window movement
      {
        commands = ["move --direction left"];
        bindings = ["alt+shift+h" "alt+shift+left"];
      }
      {
        commands = ["move --direction right"];
        bindings = ["alt+shift+l" "alt+shift+right"];
      }
      {
        commands = ["move --direction up"];
        bindings = ["alt+shift+k" "alt+shift+up"];
      }
      {
        commands = ["move --direction down"];
        bindings = ["alt+shift+j" "alt+shift+down"];
      }

      # Resize
      {
        commands = ["resize --width -2%"];
        bindings = ["alt+u"];
      }
      {
        commands = ["resize --width +2%"];
        bindings = ["alt+p"];
      }
      {
        commands = ["resize --height +2%"];
        bindings = ["alt+o"];
      }
      {
        commands = ["resize --height -2%"];
        bindings = ["alt+i"];
      }

      # Window management
      {
        commands = ["wm-enable-binding-mode --name resize"];
        bindings = ["alt+r"];
      }
      {
        commands = ["wm-toggle-pause"];
        bindings = ["alt+shift+p"];
      }
      {
        commands = ["toggle-tiling-direction"];
        bindings = ["alt+v"];
      }
      {
        commands = ["wm-cycle-focus"];
        bindings = ["alt+space"];
      }
      {
        commands = ["toggle-floating --centered"];
        bindings = ["alt+shift+space"];
      }
      {
        commands = ["toggle-tiling"];
        bindings = ["alt+t"];
      }
      {
        commands = ["toggle-fullscreen"];
        bindings = ["alt+f"];
      }
      {
        commands = ["toggle-minimized"];
        bindings = ["alt+m"];
      }
      {
        commands = ["close"];
        bindings = ["alt+shift+q"];
      }

      # System
      {
        commands = ["wm-exit"];
        bindings = ["alt+shift+e"];
      }
      {
        commands = ["wm-reload-config"];
        bindings = ["alt+shift+r"];
      }
      {
        commands = ["wm-redraw"];
        bindings = ["alt+shift+w"];
      }
      {
        commands = ["shell-exec wt"];
        bindings = ["ctrl+alt+t"];
      }

      # Workspace navigation
      {
        commands = ["focus --next-active-workspace"];
        bindings = ["alt+s"];
      }
      {
        commands = ["focus --prev-active-workspace"];
        bindings = ["alt+a"];
      }
      {
        commands = ["focus --recent-workspace"];
        bindings = ["alt+d"];
      }

      # Workspace movement
      {
        commands = ["move-workspace --direction left"];
        bindings = ["alt+shift+a"];
      }
      {
        commands = ["move-workspace --direction right"];
        bindings = ["alt+shift+f"];
      }
      {
        commands = ["move-workspace --direction up"];
        bindings = ["alt+shift+d"];
      }
      {
        commands = ["move-workspace --direction down"];
        bindings = ["alt+shift+s"];
      }
    ];
  };

  # Generate the complete configuration using our helper functions
  workspaces =
    glazeWMConfig.generateWorkspaces
    (lib.take glazeWMConfig.monitorCount glazeWMConfig.monitorLabels)
    glazeWMConfig.workspacesPerMonitor;

  workspaceSwitchKeybindings =
    glazeWMConfig.generateWorkspaceKeybindings
    (lib.take glazeWMConfig.monitorCount glazeWMConfig.monitorLabels)
    glazeWMConfig.workspacesPerMonitor
    "focus";

  workspaceMoveKeybindings =
    glazeWMConfig.generateWorkspaceKeybindings
    (lib.take glazeWMConfig.monitorCount glazeWMConfig.monitorLabels)
    glazeWMConfig.workspacesPerMonitor
    "move";

  allKeybindings =
    glazeWMConfig.standardKeybindings
    ++ workspaceSwitchKeybindings
    ++ workspaceMoveKeybindings;
in {
  imports = [
    ../shared.nix
    ../../../modules/home/profiles/features.nix
  ];

  # Feature-based configuration for WSL work environment
  features = {
    development = {
      enable = true;
      languages = ["nix" "python" "go" "rust" "javascript"];
    };

    # Enable work-specific tools
    work = {
      enable = true;
    };
  };

  # WSL-specific home configuration
  # Focus on terminal applications and CLI tools
  programs = {
    # Enable direnv for project-specific environments
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    # Enhanced shell experience
    starship.enable = true;
    zoxide.enable = true;

    # Git configuration (likely already in shared.nix)
    git.enable = true;
  };

  # WSL-specific environment variables
  home.sessionVariables = {
    # Help with WSL display issues if X11 forwarding is used
    DISPLAY = ":0";
    # Optimize for WSL environment
    WSL_DISTRO_NAME = "nixos";
  };

  # GlazeWM configuration management
  home.file = {
    # Main GlazeWM configuration file - generated dynamically
    ".glzr/glazewm/config.yaml".text = lib.generators.toYAML {} {
      general = {
        config_reload_commands = [];
        focus_follows_cursor = false;
        toggle_workspace_on_refocus = false;
        cursor_jump = {
          enabled = true;
          trigger = "monitor_focus";
        };
        hide_method = "cloak";
        show_all_in_taskbar = true;
      };

      gaps = {
        scale_with_dpi = true;
        inner_gap = "10px";
        outer_gap = {
          top = "10px";
          right = "10px";
          bottom = "10px";
          left = "10px";
        };
      };

      window_effects = {
        focused_window = {
          border = {
            enabled = true;
            color = "#8dbcff";
          };
          hide_title_bar = {
            enabled = false;
          };
          corner_style = {
            enabled = true;
            style = "rounded";
          };
          transparency = {
            enabled = true;
            opacity = "95%";
          };
        };
        other_windows = {
          border = {
            enabled = true;
            color = "#a1a1a1";
          };
          hide_title_bar = {
            enabled = true;
          };
          corner_style = {
            enabled = true;
            style = "rounded";
          };
          transparency = {
            enabled = true;
            opacity = "95%";
          };
        };
      };

      window_behavior = {
        initial_state = "tiling";
        state_defaults = {
          floating = {
            centered = true;
            shown_on_top = true;
          };
          fullscreen = {
            maximized = true;
            shown_on_top = false;
          };
        };
      };

      # Dynamically generated workspaces
      inherit workspaces;

      # Extracted window rules for easier maintenance
      window_rules = glazeWMConfig.standardWindowRules;

      binding_modes = [
        {
          name = "resize";
          keybindings = [
            {
              commands = ["resize --width -2%"];
              bindings = ["h" "left"];
            }
            {
              commands = ["resize --width +2%"];
              bindings = ["l" "right"];
            }
            {
              commands = ["resize --height +2%"];
              bindings = ["k" "up"];
            }
            {
              commands = ["resize --height -2%"];
              bindings = ["j" "down"];
            }
            {
              commands = ["wm-disable-binding-mode --name resize"];
              bindings = ["escape" "enter"];
            }
          ];
        }
      ];

      # Dynamically generated keybindings
      keybindings = allKeybindings;
    };

    # Workspace management scripts
    ".glzr/glazewm/scripts/workspaceAction.js" = {
      executable = true;
      text = ''
        // File: workspaceAction.js
        /**
         * Performs workspace action (focus/move) based on current monitor
         * Required Arguments: <action> <workspace1> [workspace2] [workspace3] ...
         * Actions: focus, move
         *
         * Example:
         *   node workspaceAction.js focus a1 b1 c1
         *   node workspaceAction.js move a1 b1 c1
         *
         * Workspaces should be provided in the same order as monitors.
         * For example, if you have 3 monitors and want to map them to a1, b1, c1:
         *   - "focus a1 b1 c1" will focus the correct workspace depending on which monitor is active
         *   - "move a1 b1 c1" will move the focused window to the corresponding workspace
         */
        import { WmClient } from 'glazewm';

        const args = process.argv.slice(2);
        if (args.length < 2) {
            console.log('Usage: node workspaceAction.js <focus|move> <workspace1> [workspace2] ...');
            process.exit(0);
        }

        const [action, ...workspaces] = args;
        if (!action || !['focus', 'move'].includes(action)) {
            console.error('Invalid action. Use "focus" or "move".');
            process.exit(1);
        }

        const client = new WmClient();
        client.onConnect(async () => {
            const { monitors } = await client.queryMonitors();
            const index = monitors.findIndex(m => m.hasFocus);

            if (index < 0 || index >= workspaces.length) {
                console.warn(`Index: [''${index}] out of workspaces.length(''${workspaces.length}) bounds.`);
            } else {
                await client.runCommand(`''${action} --workspace ''${workspaces[index]}`);
                if (action === 'move') {
                    await client.runCommand(`focus --workspace ''${workspaces[index]}`);
                }
            }

            process.exit(0);
        });
      '';
    };

    ".glzr/glazewm/scripts/package.json".text = ''
      {
        "name": "glazewm-workspace-scripts",
        "version": "1.0.0",
        "type": "module",
        "dependencies": {
          "glazewm": "^1.7.0",
          "ws": "^8.18.3"
        }
      }
    '';
  };
}
