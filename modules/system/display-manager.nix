{
  lib,
  pkgs,
  inputs,
  config,
  hostConfig,
  ...
}: let
  supportedWms = [
    "cosmic"
    "niri"
  ];
  invalidWms = builtins.filter (wm: !(builtins.elem wm supportedWms)) hostConfig.wms;

  # Get first available WM for defaults
  firstWm =
    if hostConfig.wms != []
    then builtins.head hostConfig.wms
    else "niri";

  # Command mapping for tuigreet sessions
  getSessionCommand = wm:
    if wm == "cosmic"
    then "cosmic-session"
    else if wm == "niri"
    then "${inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri-unstable}/bin/niri-session"
    else builtins.throw "Unsupported window manager for greetd: ${wm}";

  # Auto-login command based on WM
  autoLoginCommand = getSessionCommand firstWm;
in
  # The gate must read the RESOLVED option (config.hostConfig): the specialArgs
  # hostConfig is the static lib/hosts.nix registry, which has no
  # autoStartSession field — `or true` there kept greetd + xserver running on
  # every host whose host file assigns autoStartSession = false (m920q has
  # shipped with a greeter on tty1 this whole time). wms/isGui still come from
  # the static copy; host files assign those from the same lib values.
  lib.mkIf (hostConfig.wms != [] && !(hostConfig.isWsl or false) && config.hostConfig.autoStartSession) {
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
        settings =
          {
            default_session = {
              command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions /run/current-system/sw/share/wayland-sessions:/run/current-system/sw/share/xsessions --cmd '${autoLoginCommand}'";
              user = "greeter";
            };
          }
          // lib.optionalAttrs
          (
            config.hostConfig ? autoLogin
            && config.hostConfig.autoLogin ? enable
            && config.hostConfig.autoLogin.enable
          )
          {
            initial_session = {
              command = autoLoginCommand;
              user = config.hostConfig.autoLogin.user or config.hostConfig.user;
            };
          };
      };

      # Allow tuigreet to handle session selection
      # displayManager.defaultSession = sessionName;
    };

    environment = {
      systemPackages = with pkgs; [
        mesa
        # Additional packages for theming
        bibata-cursors
        nerd-fonts.jetbrains-mono
        catppuccin-papirus-folders
      ];

      # Consistent cursor theme variables for the Wayland session
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
