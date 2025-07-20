{
  lib,
  pkgs,
  hostConfig,
  ...
}: let
  # Get first available WM for defaults
  firstWm =
    if hostConfig.wm != []
    then builtins.head hostConfig.wm
    else "hyprland";

  # Map WM names to proper session names
  sessionName =
    if firstWm == "gnome"
    then "gnome"
    else if firstWm == "cosmic"
    then "cosmic"
    else "hyprland";

  # Auto-login command based on WM
  autoLoginCommand =
    if firstWm == "gnome"
    then "${pkgs.gnome-session}/bin/gnome-session --session=gnome"
    else if firstWm == "cosmic"
    then "cosmic-session"
    else "${pkgs.hyprland}/bin/Hyprland";
in {
  services = {
    xserver = {
      enable = true;
      videoDrivers = ["amdgpu"];
    };

    greetd = lib.mkIf (!builtins.elem "gnome" hostConfig.wm) {
      enable = true;
      settings.default_session = {
        command = "${pkgs.hyprland}/bin/Hyprland --config /etc/greetd/hyprland.conf";
        user = "greeter";
      };
      vt = 1;
      settings.initial_session = lib.mkIf (hostConfig ? autoLogin && hostConfig.autoLogin ? enable && hostConfig.autoLogin.enable) {
        command = autoLoginCommand;
        user = hostConfig.autoLogin.user or hostConfig.user;
      };
    };

    displayManager.defaultSession = sessionName;

    displayManager.gdm = lib.mkIf (builtins.elem "gnome" hostConfig.wm) {
      enable = true;
      wayland = true;
      autoSuspend = false;
    };

    gnome = lib.mkIf (builtins.elem "gnome" hostConfig.wm) {
      core-apps.enable = true;
    };
  };

  environment.systemPackages = with pkgs;
    [
      mesa
      # Additional packages for theming
      bibata-cursors
      nerd-fonts.jetbrains-mono
      catppuccin-papirus-folders
    ]
    ++ lib.optionals (builtins.elem "gnome" hostConfig.wm) [
      gnome-session
      gnome-shell
    ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [amdvlk];
    };
    usb-modeswitch.enable = true;
  };

  security.pam.services.greetd.enableGnomeKeyring = lib.mkIf (builtins.elem "gnome" hostConfig.wm) true;

  fonts.packages = with pkgs; [
    liberation_ttf
    dejavu_fonts
  ];

  users.users.greeter = {
    isSystemUser = true;
    group = "greeter";
    extraGroups = ["video" "render"];
  };

  users.groups.greeter = {};

  # Create log, runtime, and cache directories for regreet
  systemd.tmpfiles.rules = [
    "d /var/log/regreet 0755 greeter greeter -"
    "d /run/user/988 0700 greeter greeter -"
    "d /var/lib/regreet 0755 greeter greeter -"
  ];

  # Ensure regreet has proper environment for GUI
  systemd.services.greetd.environment = {
    XDG_SESSION_CLASS = "greeter";
    XDG_SESSION_TYPE = "wayland";
    XDG_RUNTIME_DIR = "/run/user/988";
    WAYLAND_DISPLAY = "wayland-0";
  };

  # Use consistent environment variables from Hyprland configuration
  environment.variables = {
    XCURSOR_THEME = "Bibata-Modern-Classic";
    XCURSOR_SIZE = "24";
    HYPRCURSOR_THEME = "Bibata-Modern-Classic";
    HYPRCURSOR_SIZE = "24";
  };

  # Configure regreet using NixOS options
  programs.regreet = {
    enable = true;
    theme = {
      name = "catppuccin-mocha";
      package = pkgs.catppuccin-gtk.override {
        accents = ["blue"];
        size = "compact";
        variant = "mocha";
      };
    };
    settings = {
      background = {
        path = "/per/etc/nixos/modules/home/wallpapers/solar-system.jpg";
        fit = "Cover";
      };
      GTK = {
        application_prefer_dark_theme = true;
      };
      commands = {
        reboot = ["systemctl" "reboot"];
        poweroff = ["systemctl" "poweroff"];
      };
      appearance = {
        greeting_msg = "Welcome back!";
      };
    };
    extraCss = ''
      /* Catppuccin Mocha theme with blur effects */
      window {
        background-color: rgba(30, 30, 46, 0.85);
        backdrop-filter: blur(20px);
        -webkit-backdrop-filter: blur(20px);
        color: #cdd6f4;
      }

      .main-container {
        background-color: rgba(49, 50, 68, 0.9);
        backdrop-filter: blur(25px);
        -webkit-backdrop-filter: blur(25px);
        border-radius: 16px;
        border: 1px solid rgba(166, 173, 200, 0.2);
        box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
      }

      /* Input field styling */
      entry {
        background-color: rgba(69, 71, 90, 0.8);
        color: #cdd6f4;
        border: 2px solid rgba(166, 173, 200, 0.3);
        border-radius: 12px;
        padding: 12px;
        font-size: 14px;
      }

      entry:focus {
        border-color: #89b4fa;
        box-shadow: 0 0 12px rgba(137, 180, 250, 0.4);
        background-color: rgba(69, 71, 90, 0.9);
      }

      /* All buttons - consistent styling */
      button {
        background-color: rgba(137, 180, 250, 0.8);
        color: #1e1e2e;
        border-radius: 12px;
        border: none;
        padding: 12px 20px;
        font-weight: 600;
        font-size: 14px;
        transition: all 0.2s ease;
      }

      button:hover {
        background-color: rgba(137, 180, 250, 0.95);
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(137, 180, 250, 0.3);
      }

      button:active {
        transform: translateY(0);
      }

      /* Ensure all text is white for readability */
      label {
        color: #cdd6f4;
        font-weight: 500;
      }

      .greeting {
        color: #cdd6f4;
        font-weight: 700;
        text-shadow: 0 2px 4px rgba(0, 0, 0, 0.3);
      }

      /* Power/reboot buttons - keep consistent blue theme */
      .power-button, .reboot-button {
        background-color: rgba(137, 180, 250, 0.8);
        color: #1e1e2e;
      }

      .power-button:hover, .reboot-button:hover {
        background-color: rgba(137, 180, 250, 0.95);
      }

      /* Additional blur for overlay elements */
      .overlay {
        backdrop-filter: blur(30px);
        -webkit-backdrop-filter: blur(30px);
      }
    '';
  };

  # Hyprland configuration for regreet
  environment.etc."greetd/hyprland.conf".text = ''
    # Disable some effects to speed up startup
    misc {
      disable_hyprland_logo = true
      disable_splash_rendering = true
      disable_hyprland_qtutils_check = true
    }

    # Environment variables to prevent issues
    env = GTK_USE_PORTAL,0
    env = GDK_DEBUG,no-portals

    # Launch regreet and exit when done
    exec-once = ${pkgs.greetd.regreet}/bin/regreet; hyprctl dispatch exit
  '';

  boot.kernelParams = ["usbcore.autosuspend=-1"];
}
