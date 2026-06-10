{
  lib,
  pkgs,
  hostConfig,
  ...
}: let
  supportedWms = [
    "gnome"
    "cosmic"
    "niri"
    "hyprland"
  ];
  invalidWms = builtins.filter (wm: !(builtins.elem wm supportedWms)) hostConfig.wms;

  # Get first available WM for defaults
  firstWm =
    if hostConfig.wms != []
    then builtins.head hostConfig.wms
    else "hyprland";

  # Map WM names to proper session names
  # sessionName =
  #   if firstWm == "gnome"
  #   then "gnome"
  #   else if firstWm == "cosmic"
  #   then "cosmic"
  #   else "hyprland";

  # Command mapping for tuigreet sessions
  getSessionCommand = wm:
    if wm == "gnome"
    then "${pkgs.gnome-session}/bin/gnome-session --session=gnome"
    else if wm == "cosmic"
    then "cosmic-session"
    else if wm == "niri"
    then "${pkgs.niri}/bin/niri-session"
    else "${pkgs.hyprland}/bin/Hyprland";

  # Auto-login command based on WM
  autoLoginCommand = getSessionCommand firstWm;
  # Build tuigreet session list with all available WMs
  # sessionsList = builtins.concatStringsSep "," (map (
  #     wm: let
  #       sessionCmd = getSessionCommand wm;
  #       sessionLabel =
  #         if wm == "gnome"
  #         then "GNOME"
  #         else if wm == "cosmic"
  #         then "COSMIC"
  #         else "Hyprland";
  #     in "${sessionLabel}:${sessionCmd}"
  #   )
  #   hostConfig.wms);
in
  lib.mkIf (hostConfig.wms != [] && !(hostConfig.isWsl or false)) {
    assertions = [
      {
        assertion = hostConfig.isGui;
        message = "display-manager.nix requires hostConfig.isGui = true when hostConfig.wms is non-empty";
      }
      {
        assertion = invalidWms == [];
        message = "display-manager.nix received unsupported window managers in hostConfig.wms: ${builtins.concatStringsSep ", " invalidWms}";
      }
    ];

    services = {
      xserver = {
        enable = true;
        videoDrivers = ["amdgpu"];
      };

      # Use tuigreet for all window managers
      greetd = {
        enable = true;
        useTextGreeter = true;
        settings.default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions:/run/current-system/sw/share/xsessions --cmd '${autoLoginCommand}'";
          user = "greeter";
        };
        settings.initial_session =
          lib.mkIf (hostConfig ? autoLogin && hostConfig.autoLogin ? enable && hostConfig.autoLogin.enable)
          {
            command = autoLoginCommand;
            user = hostConfig.autoLogin.user or hostConfig.user;
          };
      };

      # Allow tuigreet to handle session selection
      # displayManager.defaultSession = sessionName;

      gnome = lib.mkIf (builtins.elem "gnome" hostConfig.wms) {
        core-apps.enable = true;
      };
    };

    environment = {
      systemPackages = with pkgs;
        [
          mesa
          # Additional packages for theming
          bibata-cursors
          nerd-fonts.jetbrains-mono
          catppuccin-papirus-folders
        ]
        ++ lib.optionals (builtins.elem "gnome" hostConfig.wms) [
          gnome-session
          gnome-shell
        ]
        ++ lib.optionals (builtins.elem "hyprland" hostConfig.wms) [
          hyprland
        ];

      # Use consistent environment variables from Hyprland configuration
      variables = {
        XCURSOR_THEME = "Bibata-Modern-Classic";
        XCURSOR_SIZE = "24";
        HYPRCURSOR_THEME = "Bibata-Modern-Classic";
        HYPRCURSOR_SIZE = "24";
      };

      # Ensure session files are available for tuigreet
      pathsToLink = [
        "/share/wayland-sessions"
        "/share/xsessions"
      ];
    };

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };
      usb-modeswitch.enable = true;
    };

    # Enable GNOME keyring for all sessions that might need it
    security.pam.services.greetd.enableGnomeKeyring = builtins.elem "gnome" hostConfig.wms;

    fonts.packages = with pkgs; [
      liberation_ttf
      dejavu_fonts
    ];

    users.users.greeter = {
      isSystemUser = true;
      group = "greeter";
      extraGroups = [
        "video"
        "render"
        "tty"
      ];
    };

    users.groups.greeter = {};

    boot.kernelParams = ["usbcore.autosuspend=-1"];
  }
