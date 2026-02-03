{
  inputs,
  lib,
  ...
}: let
  hostLib = import ../helpers.nix;
  hostName = "hp-probook-vmware";
  hostInfo = inputs.self.lib.hostData.${hostName};
in {
  imports =
    [
      ./disko.nix
      ../shared-gui.nix
      ../../modules/system/stylix-catppuccin.nix
      ../../modules/system/performance-profiles.nix
    ]
    ++ hostLib.wmModules hostInfo.wms;

  # Host-specific configuration using centralized host mapping
  hostConfig = {
    inherit hostName;
    inherit (hostInfo) isGui;
    wm = hostInfo.wms;
    # user and system use defaults from lib/defaults.nix

    # Performance profile for VMware guest (maximum performance)
    performanceProfile = "build";

    # Enable auto-login for VM convenience
    autoLogin = {
      enable = true;
      user = "schausberger";
    };
  };

  # Stylix theme management using shared Catppuccin Mocha module
  modules.system.stylix-catppuccin = {
    enable = true;
    # Use custom font packages from inputs for VMware
    fontPackages = {
      monospace = inputs.nixpkgs.legacyPackages.x86_64-linux.nerd-fonts.jetbrains-mono;
      sansSerif = inputs.nixpkgs.legacyPackages.x86_64-linux.inter;
      serif = inputs.nixpkgs.legacyPackages.x86_64-linux.merriweather;
    };
    cursorPackage = inputs.nixpkgs.legacyPackages.x86_64-linux.bibata-cursors;
  };

  # Hardware configuration
  # Disable AMD GPU profile for VM (uses VMware graphics)
  hardware.profiles.amdGpu.enable = lib.mkForce false;

  # Override video drivers for VMware
  services.xserver.videoDrivers = lib.mkForce ["vmware" "modesetting"];

  # Keyboard layout configuration
  # Note: When using "Edit → Paste" from Windows host to VM, characters may be translated
  # incorrectly (e.g., - becomes ß, y becomes z). This happens when the Windows host keyboard
  # layout differs from the VM's layout. To fix: Configure Windows host to use German keyboard
  # layout via Settings → Time & Language → Language & Region → Add German keyboard.
  # Using VMware Tools clipboard (Ctrl+C/Ctrl+V) avoids this issue.
  services.xserver.xkb = {
    layout = "de";
    variant = "";
  };

  # Sync console keyboard layout with X11 configuration
  console.useXkbConfig = true;

  # System modules configuration
  modules.system = {
    containers.enable = true;
    maintenance = {
      enable = true;
      autoUpdate.enable = true;
      monitoring = {
        enable = true;
        alerts = true;
      };
    };
  };

  # Disable smartd for VM (VMware virtual disks don't support SMART)
  services.smartd.enable = lib.mkForce false;

  # VMware Guest Performance Optimizations
  # These settings optimize NixOS for running inside a VMware VM
  #
  # Setting Priority Hierarchy (3 layers):
  # 1. Core defaults (system/core/default.nix) - Global baseline, no priority
  # 2. Build profile (performance-profiles.nix) - lib.mkDefault, overrides core
  # 3. VMware-specific (this file) - lib.mkForce where needed, highest priority
  #
  # Inherited from core defaults (system/core):
  # - Network: 128MB TCP buffers, BBR congestion control
  # - Memory: Basic dirty page settings (10/5)
  # - Security: Kernel pointer restriction, reverse path filtering
  #
  # Inherited from build profile (performanceProfile = "build"):
  # - vm.swappiness = 1 (avoid swap, overrides core's 10)
  # - vm.vfs_cache_pressure = 50 (keep inode/dentry cache)
  # - powerManagement.cpuFreqGovernor = "performance" (max CPU speed)
  # - mitigations=off, nowatchdog (kernel params for performance)
  # - vm.dirty_ratio = 40, vm.dirty_background_ratio = 10 (build-optimized)
  #
  # VMware-specific overrides (this file, lib.mkForce):
  # - Dirty page writeback: 15/5 (more aggressive than build's 40/10 for VM I/O)
  # - Network buffers: 16MB (smaller than core's 128MB, appropriate for VM)
  # - I/O scheduler: 'none' (VMware hypervisor handles scheduling)
  # - Graphics: Force vmwgfx Mesa driver for VMware SVGA 3D

  # Graphics optimization for VMware
  # Mesa vmwgfx driver has rendering bugs causing blocks to disappear in Minecraft
  # Software rendering (llvmpipe) bypasses the buggy driver and renders correctly
  environment.sessionVariables = {
    # Force software rendering to work around Mesa vmwgfx driver bugs
    # Minecraft 1.21+ has invisible blocks issue with Mesa 25.3.2 vmwgfx hardware rendering
    # Software rendering is slower but stable
    LIBGL_ALWAYS_SOFTWARE = "1";

    # Force Mesa to use VMware SVGA 3D driver (when not using software rendering)
    MESA_LOADER_DRIVER_OVERRIDE = "vmwgfx";

    # Override reported OpenGL version to match VMware hardware capabilities
    # VMware Workstation 17+ with HW v20+ supports OpenGL 4.3
    # Ghostty requires OpenGL 4.3+, which VMware now provides
    MESA_GL_VERSION_OVERRIDE = "4.3";

    # Enable Gallium HUD for performance monitoring (optional)
    # GALLIUM_HUD = "fps";
  };

  # I/O scheduler optimization for VMware virtual disks
  # VMware handles I/O scheduling at the hypervisor level
  services.udev.extraRules = ''
    # Use 'none' scheduler for VMware virtual SCSI disks (best for VMs)
    ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/scheduler}="none"
    # Use 'none' scheduler for NVMe devices in VMware
    ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
  '';

  # Memory and kernel tuning for VMware guest
  # VMware-specific optimizations that override both core defaults and build profile
  boot.kernel.sysctl = {
    # VMware-specific dirty page writeback tuning
    # Overrides core defaults (10/5) and build profile (40/10)
    # More aggressive for better VM I/O responsiveness, reduces stuttering
    "vm.dirty_ratio" = lib.mkForce 15;
    "vm.dirty_background_ratio" = lib.mkForce 5;
    "vm.dirty_writeback_centisecs" = lib.mkForce 100;
    "vm.dirty_expire_centisecs" = lib.mkForce 1000;

    # Disable zone reclaim (better for NUMA, doesn't hurt single-socket)
    "vm.zone_reclaim_mode" = 0;

    # Network performance tuning for VMware paravirtual network (vmxnet3)
    # Overrides core defaults (128MB buffers) with smaller 16MB buffers for VM
    "net.core.netdev_max_backlog" = lib.mkForce 5000;
    "net.core.rmem_max" = lib.mkForce 16777216;
    "net.core.wmem_max" = lib.mkForce 16777216;
    "net.ipv4.tcp_rmem" = lib.mkForce "4096 87380 16777216";
    "net.ipv4.tcp_wmem" = lib.mkForce "4096 65536 16777216";
    "net.ipv4.tcp_timestamps" = 1;
    "net.ipv4.tcp_window_scaling" = 1;
  };

  # ZFS with impermanence (matching physical hosts)
  # The VM now uses the same ZFS structure as desktop/surface for consistency
  # Disko creates the filesystems, but we need to set neededForBoot for impermanence

  # Required for impermanence: /per must be mounted early in boot
  fileSystems."/per".neededForBoot = true;

  # Disable systemd-initrd for VM compatibility with ZFS
  # The systemd-initrd has a known issue with ZFS path resolution (assertion error)
  # Use traditional dracut-based initrd instead for reliable ZFS import
  boot.initrd.systemd.enable = lib.mkForce false;

  # File systems - add neededForBoot for ephemeral storage
  fileSystems."/home".neededForBoot = true;
}
