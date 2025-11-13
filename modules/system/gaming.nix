_: {
  # Centralized gaming and performance optimizations
  # This module provides gaming hardware support and performance tuning

  # Gaming hardware support
  hardware.steam-hardware.enable = true;

  # Security configuration for better gaming performance
  security.pam.loginLimits = [
    # Real-time scheduling for better audio/gaming performance
    {
      domain = "@users";
      item = "rtprio";
      type = "-";
      value = "1";
    }
    {
      domain = "@users";
      item = "nice";
      type = "-";
      value = "-11";
    }
    {
      domain = "@users";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
  ];

  # GameMode for automatic game optimizations
  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10;
        ioprio = 4;
        inhibit_screensaver = 1;
      };

      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        amd_performance_level = "high";
      };
    };
  };
}
