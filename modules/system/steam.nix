{
  config,
  lib,
  pkgs,
  ...
}: {
  options.modules.system.steam = {
    enable = lib.mkEnableOption "Steam gaming runtime";
    autoStart = lib.mkEnableOption "Auto-start Steam on graphical login";
    extraLibraryFolders = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional Steam library folders to register in libraryfolders.vdf (e.g. a games pool mount)";
      example = ["/per/mnt/games/SteamLibrary"];
    };
  };

  config = lib.mkIf config.modules.system.steam.enable {
    assertions = [
      {
        assertion = config.programs.gamemode.enable;
        message = "modules.system.steam.enable requires programs.gamemode.enable for GAMEMODERUN integration";
      }
    ];

    hardware.steam-hardware.enable = true;

    systemd.user.services.steam-autostart = lib.mkIf config.modules.system.steam.autoStart {
      description = "Steam Client Auto-start";
      after = ["graphical-session.target"];
      wants = ["graphical-session.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${config.programs.steam.package}/bin/steam -silent";
        Restart = "on-failure";
        RestartSec = 10;
      };
      wantedBy = ["graphical-session.target"];
    };

    programs.steam = {
      enable = true;
      # Declarative Proton GE for Steam Play; replaces manual
      # STEAM_EXTRA_COMPAT_TOOLS_PATHS handling per NixOS wiki Proton section
      extraCompatPackages = with pkgs; [
        proton-ge-bin
      ];
      # pactl client for Steam audio device handling (host is PipeWire-only,
      # so the pactl calls in the startup log fail without this)
      extraPackages = with pkgs; [
        pulseaudio
      ];
      package = pkgs.steam.override {
        extraEnv = {
          # AMD GPU: use RADV open-source Vulkan driver
          AMD_VULKAN_ICD = "RADV";

          # Proton: use a local shader cache instead of Steam's shared cache
          PROTON_LOCAL_SHADER_CACHE = "1";

          # Mesa: increase shader and pipeline cache limits for large game libraries
          MESA_SHADER_CACHE_MAX_SIZE = "16G";
          MESA_GLSL_CACHE_MAX_SIZE = "16G";

          # Per-game launch options (Steam → Properties), not global env:
          # MangoHud: MANGOHUD=1 mangohud %command%
          # GameMode: gamemoderun %command%
          # DXR tiers: VKD3D_CONFIG=dxr,dxr11 %command%
          # FSR4 RDNA3: PROTON_ADD_CONFIG=fsr4rdna3 %command%
        };
      };
    };
  };
}
