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
  zellijM920qGuid = "{ddea1859-4521-504c-81d0-0196754902b0}";
  # uuid3 over a stable namespace label; the WT profile registry matches on it.
  herdrM920qGuid = "{0188e581-cf5a-31cb-b6a2-07b288087b0f}";
  m920qPlainGuid = "{e562bbda-5dbc-3276-9a8c-f05a1d604d03}";

  # wsl.exe sometimes fails before fish starts: it reports "Error code:
  # Wsl/Service/0x8007274c" (timeout on the WSL service socket) and exits -1,
  # which closed the tab without any mosh output. Process exits from Linux are
  # always 0-255, so a negative $LASTEXITCODE can only be the Windows-side
  # session creation failing; that gets exactly one retry, while mosh and ssh
  # failures (>= 0) keep their own exit code. The explicit title keeps the tab
  # labelled like the profile instead of the powershell.exe path until mosh
  # sends its own.
  zellijM920qCommandline =
    "powershell.exe -NoProfile -Command \""
    + "$Host.UI.RawUI.WindowTitle = 'm920q zellij'; "
    + "& wsl.exe -d NixOS -- fish -c m920q; "
    + "if ($LASTEXITCODE -lt 0) "
    + "{ Write-Host '[wsl] session start failed, retrying'; "
    + "& wsl.exe -d NixOS -- fish -c m920q }; "
    + "exit $LASTEXITCODE\"";

  # Same WSL-retry wrapper as the zellij profile above, but the remote entry
  # point is the agent layer: the m920q-herdr fish function lands straight
  # in the herdr TUI (mosh command override -> fish -c hattach). fish runs
  # non-interactive there, which is what keeps the zellij auto-attach hook
  # - it requires `status is-interactive` - from firing on this path.
  herdrM920qCommandline =
    "powershell.exe -NoProfile -Command \""
    + "$Host.UI.RawUI.WindowTitle = 'm920q herdr'; "
    + "& wsl.exe -d NixOS -- fish -c m920q-herdr; "
    + "if ($LASTEXITCODE -lt 0) "
    + "{ Write-Host '[wsl] session start failed, retrying'; "
    + "& wsl.exe -d NixOS -- fish -c m920q-herdr }; "
    + "exit $LASTEXITCODE\"";

  # Native Windows OpenSSH rather than the WSL/mosh path: the remote command
  # runs bash directly, so fish's zellij auto-attach never fires and the
  # session stays a plain SSH shell. The Windows `m920q` SSH alias supplies
  # the host, key and LAN/tailnet routing; no extra .ssh/config entry is
  # required.
  m920qPlainCommandline = "ssh.exe -t m920q \"exec /run/current-system/sw/bin/bash --noprofile --norc -i\"";
in {
  options.tui.windows-terminal = {
    enable =
      lib.mkEnableOption "Windows Terminal settings deployment to Windows"
      // {
        default = true;
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
      keybindings = [
        # Open the native dssh tab directly (Ctrl+Alt+D)
        {
          command = {
            action = "newTab";
            profile = dsshGuid;
          };
          keys = "ctrl+alt+d";
        }
        # Open the Zellij session on m920q directly (Ctrl+Alt+Z). Prefer this
        # over plain ssh for interactive zellij work: mosh survives IP changes
        # and suspend, and it preserves SSH_CONNECTION on the server, so the
        # fish zellij auto-attach still fires on m920q.
        {
          command = {
            action = "newTab";
            profile = zellijM920qGuid;
          };
          keys = "ctrl+alt+z";
        }
        # Agent layer twin (Ctrl+Alt+H): same mosh transports, but the remote
        # command override skips the interactive zellij auto-attach, so the
        # tab lands straight in the herdr TUI - the same panes, sidebar and
        # agent state as the homelab session.
        {
          command = {
            action = "newTab";
            profile = herdrM920qGuid;
          };
          keys = "ctrl+alt+h";
        }
      ];
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
          # Acrylic alone leaves the profile at the schema's effective
          # opacity, which has been version-dependent; pin it so the
          # frosted background is not silently opaque. Windows Settings >
          # Personalization > Colors > Transparency effects must also be on.
          opacity = 90;
          # A BEL becomes sound plus window/taskbar flash on every channel;
          # on builds whose BellStyle carries the notification flag (Preview
          # 1.26, All = 0xffffffff) the same value also raises a Windows
          # toast. Stable 1.25 only has sound/flash. "all" is valid on both
          # enums, so one value covers every installed channel.
          bellStyle = "all";
        };

        list = [
          {
            commandline = "wsl.exe -d NixOS";
            guid = "{105fcf10-e34e-509d-b0cf-d102eabc4568}";
            hidden = false;
            icon = "C:\\NixOS\\shortcut.ico";
            name = "NixOS";
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
          # Absolute path: avoids the bare-name resolving via a stale Windows
          # Terminal process PATH (dssh is installed via winget into
          # %LOCALAPPDATA%\Microsoft\WinGet\Links, which only newer WT
          # processes have). The Windows account name is substituted at
          # deploy time (__WT_USER__), so account names never appear in
          # this repo. Bare commandline: the tab closes when the ssh
          # session ends.
          {
            commandline = "C:\\Users\\__WT_USER__\\AppData\\Local\\Microsoft\\WinGet\\Links\\dssh.exe";
            guid = dsshGuid;
            hidden = false;
            # No icon: lets WT show its generic terminal icon so the tab is not
            # mistaken for the NixOS/WSL tab (tab title is set per-host by the
            # ssh LocalCommand in the Windows .ssh/config).
            name = "dssh";
          }
          # Zellij session on m920q, reached over mosh via WSL. dssh cannot
          # launch mosh (ssh-only launcher), so this profile wraps the fish
          # function that picks the tailscale/LAN path. Routed through the WSL
          # default-shell wrapper (no -e): a direct exec would skip
          # /etc/set-environment and miss PATH/LANG. Tab closes when the
          # session ends. The command line is the retry wrapper declared above;
          # wsl.exe itself is unchanged.
          #
          # Icon: Segoe Fluent Icons "Wifi" glyph (U+E701), same value the WT
          # settings UI writes when picking the wifi icon - distinguishes mosh
          # tabs from plain ssh tabs at a glance. Nix has no \uXXXX string
          # escape (a bare backslash is dropped silently), so the glyph is
          # parsed out of a JSON string literal via fromJSON.
          {
            commandline = zellijM920qCommandline;
            guid = zellijM920qGuid;
            hidden = false;
            icon = builtins.fromJSON ''"\ue701"'';
            name = "m920q zellij";
          }
          # Herdr attach, straight over the same mosh chain: same retries and
          # wifi glyph. Deliberately no icon/name overlap with the zellij tab
          # so the agent surface reads as its own thing.
          {
            commandline = herdrM920qCommandline;
            guid = herdrM920qGuid;
            hidden = false;
            icon = builtins.fromJSON ''"\ue701"'';
            name = "m920q herdr";
          }
          # Native Windows OpenSSH into m920q running a plain bash: no fish,
          # no Zellij, no prompt framework. Uses the existing Windows `m920q`
          # SSH alias.
          {
            commandline = m920qPlainCommandline;
            guid = m920qPlainGuid;
            hidden = false;
            name = "m920q plain";
          }
        ];
      };

      schemes = [];
      theme = "dark";
      themes = [];
      # The tab row stays opaque by default even when the profile uses
      # acrylic; frost it too so the window reads as one surface.
      useAcrylicInTabRow = true;
    };

    # Named with zz- prefix to run after writeBoundary (alphabetical ordering),
    # mirroring the WezTerm Windows deploy. Deploys to every installed Windows
    # Terminal channel: Stable, Preview and Canary are separate MSIX packages
    # (Identity Names Microsoft.WindowsTerminal, ...Preview, ...Canary) and
    # each keeps its own LocalState/settings.json, so canary would otherwise
    # never receive this file. A channel directory that exists without
    # LocalState (installed, never launched) gets one; channels that are not
    # installed simply do not match the glob, and off-Windows hosts match
    # nothing.
    home.activation.zz-windows-terminal-deploy = ''
      WT_SETTINGS="$HOME/.config/windows-terminal/settings.json"

      # The settings carry one Windows-account-absolute path (the winget
      # dssh link). Substitute the owning account per package dir before
      # copying, so account names stay out of this repo. Off-Windows hosts
      # match nothing in the loop. If a package dir yields no account the
      # __WT_USER__ placeholder is copied as-is and only the dssh profile
      # starts broken; every other profile is unaffected.
      if [ -f "$WT_SETTINGS" ]; then
        for wt_pkg in /mnt/c/Users/*/AppData/Local/Packages/Microsoft.WindowsTerminal*; do
          [ -d "$wt_pkg" ] || continue
          mkdir -p "$wt_pkg/LocalState"
          wt_user="$(basename "$(dirname "$(dirname "$(dirname "$(dirname "$wt_pkg")")")")")"
          if [ -n "$wt_user" ]; then
            sed "s/__WT_USER__/$wt_user/g" "$WT_SETTINGS" > "$wt_pkg/LocalState/settings.json"
          else
            cp "$WT_SETTINGS" "$wt_pkg/LocalState/settings.json"
          fi
        done
      fi
    '';
  };
}
