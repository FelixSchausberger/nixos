{pkgs, ...}: {
  hardware.steam-hardware.enable = true;

  programs.steam = {
    enable = true;
    package = pkgs.steam.override {
      extraEnv = {
        # MangoHud enabled for all Steam games, reads MangoHud.conf for display settings
        MANGOHUD = "1";
        MANGOHUD_CONFIG = "read_cfg,no_display";

        # GameMode: request CPU/GPU performance profile for each game launch
        GAMEMODERUN = "1";

        # AMD GPU: use RADV open-source Vulkan driver
        AMD_VULKAN_ICD = "RADV";

        # VKD3D-Proton: enable DXR (DirectX Raytracing) tiers 1.0 and 1.1
        VKD3D_CONFIG = "dxr,dxr11";

        # Proton: enable FSR4 RDNA3 upscaling
        PROTON_ADD_CONFIG = "fsr4rdna3";

        # Proton: use a local shader cache instead of Steam's shared cache
        PROTON_LOCAL_SHADER_CACHE = "1";

        # Mesa: increase shader and pipeline cache limits for large game libraries
        MESA_SHADER_CACHE_MAX_SIZE = "16G";
        MESA_GLSL_CACHE_MAX_SIZE = "16G";

        # Wine/Proton: restrict to Vulkan rendering path, skip OpenGL fallback
        WINE_VK_VULKAN_ONLY = "1";

        # Wine/Proton: use native DXVK/VKD3D for D3D and audio, builtin for rest
        WINEDLLOVERRIDES = "dinput8,dxgi,dsound=n,b";
      };
    };
  };
}
