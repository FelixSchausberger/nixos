# Windows Terminal configuration, owned by NixOS and deployed to Windows via
# a Home Manager activation script (same pattern as the WezTerm deploy in
# hosts/hp-probook-wsl/default.nix).
#
# The whole settings.json is built from a Nix attrset so colors/fonts can reuse
# repo definitions, and so the config is reproducible across hosts. Only
# settings.json is deployed; Windows owns state.json (window positions, etc).
{
  lib,
  config,
  ...
}: let
  dsshGuid = "{e0b0a5b5-4f2a-4a1d-9d88-3c5d9d1b7b01}";
in {
  options.tui.windows-terminal = {
    enable =
      lib.mkEnableOption "Windows Terminal settings deployment to Windows"
      // {
        default = true;
      };

    # Absolute path on the Windows side where settings.json is deployed.
    target = lib.mkOption {
      type = lib.types.str;
      default =
        "/mnt/c/Users/SchausbergerF/AppData/Local/Packages/"
        + "Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json";
      description = "Windows path to deploy Windows Terminal settings.json to";
    };
  };

  config = lib.mkIf config.tui.windows-terminal.enable {
    # Complete settings.json, reproducing the prior Windows-side file and
    # adding a dssh profile that launches the native dssh TUI directly.
    home.file.".config/windows-terminal/settings.json".text = builtins.toJSON {
      "$help" = "https://aka.ms/terminal-documentation";
      "$schema" = "https://aka.ms/terminal-profiles-schema";

      actions = [];
      defaultProfile = "{c5c295a4-2293-4524-90ee-b15939b7bb4f}";
      disabledProfileSources = [
        "Git"
        "Windows.Terminal.Azure"
        "Windows.Terminal.VisualStudio"
      ];
      keybindings = [];
      newTabMenu = [
        {type = "remainingProfiles";}
      ];

      profiles = {
        defaults = {
          antialiasingMode = "grayscale";
          background = "#1E1E2E";
          colorScheme = "One Half Dark";
          font = {
            face = "FiraCode Nerd Font Mono";
            size = 14;
          };
          useAcrylic = true;
        };

        list = [
          {
            commandline = "wsl.exe -d NixOS";
            guid = "{105fcf10-e34e-509d-b0cf-d102eabc4568}";
            hidden = false;
            icon = "C:\\NixOS\\shortcut.ico";
            name = "NixOS";
            startingDirectory = "C:\\Users\\SchausbergerF";
          }
          {
            guid = "{2ece5bfe-50ed-5f3a-ab87-5cd4baafed2b}";
            hidden = true;
            name = "Git Bash";
            source = "Git";
          }
          {
            guid = "{c5c295a4-2293-4524-90ee-b15939b7bb4f}";
            hidden = false;
            name = "CMD";
          }
          {
            guid = "{61c54bbd-c2c6-5271-96e7-009a87ff44bf}";
            hidden = false;
            name = "Windows PowerShell";
          }
          {
            guid = "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}";
            hidden = false;
            name = "Command Prompt";
          }
          # Native dssh TUI connection manager. Uses the Windows OpenSSH on
          # PATH, so interior ProxyCommand hosts work exactly as in WezTerm.
          # Bare commandline: the tab closes when the ssh session ends.
          {
            commandline = "dssh.exe";
            guid = dsshGuid;
            hidden = false;
            icon = "C:\\NixOS\\shortcut.ico";
            name = "dssh";
          }
        ];
      };

      schemes = [];
      theme = "dark";
      themes = [];
    };

    # Named with zz- prefix to run after writeBoundary (alphabetical ordering),
    # mirroring the WezTerm Windows deploy. Only copies if the Windows side exists.
    home.activation.zz-windows-terminal-deploy = ''
      WT_TARGET="${config.tui.windows-terminal.target}"

      if [ -f "$HOME/.config/windows-terminal/settings.json" ] && [ -d "/mnt/c/Users/SchausbergerF" ]; then
        mkdir -p "$(dirname "$WT_TARGET")"
        cp "$HOME/.config/windows-terminal/settings.json" "$WT_TARGET"
      fi
    '';
  };
}
