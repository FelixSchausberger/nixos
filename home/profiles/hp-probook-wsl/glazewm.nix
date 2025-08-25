{
  lib,
  pkgs,
  ...
}: let
  # Use proper YAML format instead of JSON
  yamlFormat = pkgs.formats.yaml {};
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
          {window_title = {equals = "Command Palette";};}
          {window_class = {regex = "Chrome_WidgetWin_1|MozillaDialogClass";};}
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

      # Workspace navigation
      {
        commands = ["focus --next-active-workspace"];
        bindings = ["alt+page_down"];
      }
      {
        commands = ["focus --prev-active-workspace"];
        bindings = ["alt+page_up"];
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
  # WSL-specific home configuration
  home = {
    # Copy GlazeWM config to Windows directory
    activation.glazewmCopy = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Try multiple methods to get Windows username
      WINDOWS_USER=""

      # Method 1: Try to get from cmd.exe
      if [ -z "$WINDOWS_USER" ]; then
        WINDOWS_USER=$(powershell.exe -Command "echo \$env:USERNAME" 2>/dev/null | tr -d '\r\n' || true)
      fi

      # Method 2: Look for existing user directories in /mnt/c/Users/
      if [ -z "$WINDOWS_USER" ] || [ "$WINDOWS_USER" = "" ]; then
        for userdir in /mnt/c/Users/*/; do
          username=$(basename "$userdir")
          # Skip system directories
          if [ "$username" != "Default" ] && [ "$username" != "Public" ] && [ "$username" != "All Users" ] && [ "$username" != "Default User" ] && [ ! "$username" = "Admin*" ] && [ -w "$userdir" 2>/dev/null ]; then
            WINDOWS_USER="$username"
            break
          fi
        done
      fi

      # Method 3: Fallback to SchausbergerF (the known working username)
      if [ -z "$WINDOWS_USER" ] || [ "$WINDOWS_USER" = "" ]; then
        WINDOWS_USER="SchausbergerF"
      fi

      WINDOWS_GLZR_DIR="/mnt/c/Users/$WINDOWS_USER/.glzr"
      WSL_GLZR_DIR="$HOME/.glzr"

      echo "Using Windows username: $WINDOWS_USER"
      echo "Windows .glzr path: $WINDOWS_GLZR_DIR"
      echo "WSL .glzr path: $WSL_GLZR_DIR"

      # Create Windows .glzr directory if it doesn't exist
      if mkdir -p "$WINDOWS_GLZR_DIR/glazewm" 2>/dev/null; then
        echo "Created/verified Windows .glzr/glazewm directory"

        # Copy files from WSL to Windows (dereference symlinks)
        if [ -d "$WSL_GLZR_DIR/glazewm" ]; then
          echo "Copying GlazeWM config files from WSL to Windows..."

          # Remove existing files first
          rm -rf "$WINDOWS_GLZR_DIR/glazewm/"* 2>/dev/null || true

          # Copy config file (dereference symlinks)
          if [ -f "$WSL_GLZR_DIR/glazewm/config.yaml" ]; then
            cp -L "$WSL_GLZR_DIR/glazewm/config.yaml" "$WINDOWS_GLZR_DIR/glazewm/config.yaml"
            echo "✓ Copied YAML config"
          fi

          # Copy scripts directory
          if [ -d "$WSL_GLZR_DIR/glazewm/scripts" ]; then
            cp -r "$WSL_GLZR_DIR/glazewm/scripts" "$WINDOWS_GLZR_DIR/glazewm/"
          fi

          echo "Copied config files to Windows"

          # Verify the copy worked
          if [ -f "$WINDOWS_GLZR_DIR/glazewm/config.yaml" ]; then
            echo "✓ config.yaml copied successfully"
          else
            echo "✗ config.yaml copy failed"
          fi

          if [ -d "$WINDOWS_GLZR_DIR/glazewm/scripts" ]; then
            echo "✓ scripts directory copied successfully"
          else
            echo "✗ scripts directory copy failed"
          fi
        else
          echo "WSL glazewm directory not found at $WSL_GLZR_DIR/glazewm"
        fi
      else
        echo "Failed to create Windows .glzr/glazewm directory at $WINDOWS_GLZR_DIR"
      fi
    '';

    # GlazeWM configuration management
    file = {
      # Main GlazeWM configuration file - generated as proper YAML
      ".glzr/glazewm/config.yaml".source = yamlFormat.generate "glazewm-config.yaml" {
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
           *
           * For single monitor setups, it will use the first workspace or fallback to the last
           * workspace if monitor index exceeds workspace count.
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

              if (index < 0) {
                  console.warn(`No monitor has focus.`);
              } else {
                  // Use Math.min to handle single monitor scenarios where index might exceed workspace count
                  const workspaceIndex = Math.min(index, workspaces.length - 1);
                  await client.runCommand(`''${action} --workspace ''${workspaces[workspaceIndex]}`);
                  if (action === 'move') {
                      await client.runCommand(`focus --workspace ''${workspaces[workspaceIndex]}`);
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

      # Development flake for the scripts directory
      ".glzr/glazewm/scripts/flake.nix".text = ''
        {
          description = "GlazeWM workspace scripts development environment";

          inputs = {
            nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
            flake-utils.url = "github:numtide/flake-utils";
          };

          outputs = { self, nixpkgs, flake-utils }:
            flake-utils.lib.eachDefaultSystem (system:
              let
                pkgs = nixpkgs.legacyPackages.''${system};
              in {
                devShells.default = pkgs.mkShell {
                  name = "glazewm-scripts";

                  buildInputs = with pkgs; [
                    nodejs_20
                    npm-check-updates
                  ];

                  shellHook = '''
                    echo "🚀 GlazeWM Scripts Development Environment"
                    echo "Node.js: $(node --version)"
                    echo "npm: $(npm --version)"
                    echo ""
                    echo "Commands:"
                    echo "  npm install                               - Install dependencies"
                    echo "  node workspaceAction.js focus a1 b1 c1   - Test focus action"
                    echo "  node workspaceAction.js move a1 b1 c1    - Test move action"
                    echo "  ncu                                       - Check for updates"
                    echo ""

                    # Auto-install dependencies if needed
                    if [[ -f "package.json" && ! -d "node_modules" ]]; then
                      echo "📦 Installing Node.js dependencies..."
                      npm install
                      echo "✅ Dependencies installed!"
                      echo ""
                    fi
                  ''';
                };
              });
        }
      '';

      # Flake lock file (empty initially)
      ".glzr/glazewm/scripts/flake.lock".text = ''
        {
          "nodes": {
            "flake-utils": {
              "inputs": {
                "systems": "systems"
              },
              "locked": {
                "lastModified": 1710146030,
                "narHash": "sha256-SZ5L6eA7HJ/nmkzGG7/ISclqe6oZdOZTNoesiInkXPQ=",
                "owner": "numtide",
                "repo": "flake-utils",
                "rev": "b1d9ab70662946ef0850d488da1c9019f3a9752a",
                "type": "github"
              },
              "original": {
                "owner": "numtide",
                "repo": "flake-utils",
                "type": "github"
              }
            },
            "nixpkgs": {
              "locked": {
                "lastModified": 1710146030,
                "narHash": "sha256-SZ5L6eA7HJ/nmkzGG7/ISclqe6oZdOZTNoesiInkXPQ=",
                "owner": "NixOS",
                "repo": "nixpkgs",
                "rev": "b1d9ab70662946ef0850d488da1c9019f3a9752a",
                "type": "github"
              },
              "original": {
                "owner": "NixOS",
                "repo": "nixpkgs",
                "rev": "nixos-unstable",
                "type": "github"
              }
            },
            "root": {
              "inputs": {
                "flake-utils": "flake-utils",
                "nixpkgs": "nixpkgs"
              }
            },
            "systems": {
              "locked": {
                "lastModified": 1681028828,
                "narHash": "sha256-Vy1rq5AaRuLzOxct8nz4T6wlgyUR7zLU309k9mBC768=",
                "owner": "nix-systems",
                "repo": "default",
                "rev": "da67096a3b9bf56a91d16901293e51ba5b49a27e",
                "type": "github"
              },
              "original": {
                "owner": "nix-systems",
                "repo": "default",
                "type": "github"
              }
            }
          },
          "root": "root",
          "version": 7
        }
      '';

      # README for the scripts directory
      ".glzr/glazewm/scripts/README.md".text = ''
        # GlazeWM Workspace Scripts

        This directory contains Node.js scripts for managing GlazeWM workspaces across multiple monitors.

        ## Development Environment

        This directory includes a Nix flake for a reproducible development environment:

        ```bash
        # Enter development environment
        nix develop

        # This automatically installs Node.js dependencies and provides:
        # - Node.js 20
        # - npm
        # - npm-check-updates (ncu)
        ```

        ## Scripts

        ### workspaceAction.js
        Handles workspace focus and window movement across multiple monitors.

        **Usage:**
        ```bash
        node workspaceAction.js <action> <workspace1> [workspace2] [workspace3]
        ```

        **Examples:**
        ```bash
        # Focus workspace 1 on the current monitor
        node workspaceAction.js focus a1 b1 c1

        # Move current window to workspace 2 on the current monitor
        node workspaceAction.js move a2 b2 c2
        ```

        ## Integration

        These scripts are called by GlazeWM keybindings defined in the NixOS configuration:
        - `Alt+1-9`: Focus workspace
        - `Alt+Shift+1-9`: Move window to workspace

        ## Dependencies

        - **glazewm**: GlazeWM client library for window manager communication
        - **ws**: WebSocket library (dependency of glazewm)

        Dependencies are automatically managed through the Nix flake development environment.
      '';
    };
  };
}
