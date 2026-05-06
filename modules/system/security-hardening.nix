{
  config,
  lib,
  ...
}: {
  options.modules.system.securityHardening = {
    enable = lib.mkEnableOption "additional kernel and network security hardening";
  };

  config = lib.mkIf config.modules.system.securityHardening.enable {
    security = {
      forcePageTableIsolation = true;
    };

    # Additional sysctl security settings
    # Note: Some settings like rp_filter, tcp_congestion_control, and default_qdisc
    # are already configured in system/core/default.nix
    boot.kernel.sysctl = {
      # Network security improvements (new additions beyond system/core)
      "net.ipv4.conf.all.log_martians" = 0; # Disable noisy martian packet logging
      "net.ipv4.conf.default.log_martians" = 0;
      "net.ipv4.conf.all.accept_source_route" = 0; # Reject source routing
      "net.ipv4.conf.default.accept_source_route" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0; # Ignore ICMP redirects
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0; # Ignore secure ICMP redirects
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv4.conf.all.send_redirects" = 0; # Don't send ICMP redirects
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.icmp_echo_ignore_broadcasts" = 1; # Ignore ICMP broadcasts
      "net.ipv4.icmp_ignore_bogus_error_responses" = 1; # Ignore bogus ICMP error responses
      "net.ipv4.tcp_syncookies" = 1; # Enable SYN flood protection
      "net.ipv6.conf.all.accept_redirects" = 0; # IPv6: Ignore ICMP redirects
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.ipv6.conf.all.accept_source_route" = 0; # IPv6: Reject source routing
      "net.ipv6.conf.default.accept_source_route" = 0;

      # TCP performance and security
      "net.ipv4.tcp_fastopen" = 3; # TCP Fast Open (client and server)

      # Kernel security improvements
      "kernel.dmesg_restrict" = 1; # Restrict dmesg access
      "kernel.kexec_load_disabled" = 1; # Disable kexec
      "kernel.unprivileged_bpf_disabled" = 1; # Disable unprivileged BPF
      "kernel.yama.ptrace_scope" = 2; # Restrict ptrace access

      # File system security
      "fs.protected_hardlinks" = 1; # Prevent hardlink attacks
      "fs.protected_symlinks" = 1; # Prevent symlink attacks
      "fs.protected_fifos" = 2; # Protect FIFOs
      "fs.protected_regular" = 2; # Protect regular files
    };
  };
}
