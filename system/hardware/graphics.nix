{pkgs, ...}: {
  # Graphics drivers and hardware acceleration
  hardware.graphics = {
    enable = true;

    # Hardware video acceleration packages
    extraPackages = with pkgs; [
      libva # Video Acceleration API
    ];

    # 32-bit hardware acceleration for compatibility
    extraPackages32 = with pkgs.pkgsi686Linux; [
      libva
    ];
  };
}
