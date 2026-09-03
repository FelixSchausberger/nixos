{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.moonshine;

  # Steam is single-instance per user: a leftover desktop Steam would receive
  # the steam:// URL instead of Moonshine's compositor and the stream fails
  # with a 503. Ask it to shut down and wait up to 30s before launching
  # (recommended workaround from hgaiser/moonshine#134).
  steamShutdown = pkgs.writeShellScript "moonshine-steam-pre-shutdown" ''
    if ${pkgs.procps}/bin/pgrep -x steam >/dev/null; then
      /run/current-system/sw/bin/steam -shutdown >/dev/null 2>&1 || true
      for i in $(${pkgs.coreutils}/bin/seq 1 30); do
        ! ${pkgs.procps}/bin/pgrep -x steam >/dev/null && break
        ${pkgs.coreutils}/bin/sleep 1
      done
    fi
  '';
  # Cover art for the Steam tile in Moonlight clients (silences the
  # "No boxart defined" warning per launch). Valve store header logo.
  steamBoxart = pkgs.fetchurl {
    url = "https://store.cloudflare.steamstatic.com/public/images/v6/globalheader_logo.png";
    sha256 = "1gccmwsnxazjqnxyqphmrw8kix0p5xpfcham02a1l8xdd91c6bmb";
  };
in {
  options.modules.system.moonshine = {
    enable = lib.mkEnableOption "Moonshine game streaming server (Moonlight protocol)";

    user = lib.mkOption {
      type = lib.types.str;
      default = config.hostConfig.user or "schausberger";
      description = "User to run Moonshine as";
    };
  };

  config = lib.mkIf cfg.enable {
    # Uses the services.moonshine module shipped in nixpkgs (upstreamed from
    # hgaiser/moonshine); importing the flake alongside it collides on the
    # services.moonshine option declarations.
    services.moonshine = {
      enable = true;
      inherit (cfg) user;

      # Xwayland hosts X11 applications (notably Steam Big Picture) inside
      # Moonshine's headless compositor; without it healthcheck warns
      # "Xwayland not found in PATH".
      extraPackages = [pkgs.xwayland];

      # eno1 for LAN clients, tailscale0 for remote Moonlight sessions.
      # The nixpkgs module replaces the old flake's global openFirewall;
      # mkDefault lets consumers retarget other interface names (VM tests).
      firewallInterfaces = lib.mkDefault ["eno1" "tailscale0"];

      settings = {
        name = "Moonshine";

        # German keyboard for in-game chat (upstream default is "us").
        compositor.keyboard.layout = "de";

        application = [
          {
            title = "Steam";
            boxart = "${steamBoxart}";
            command = [
              "/run/current-system/sw/bin/steam"
              "steam://open/bigpicture"
            ];
            # Journal logging keeps failed session launches diagnosable
            # (the default discards all application output).
            stdout = "journal";
            stderr = "journal";
            pre_command = [
              ["${pkgs.bash}/bin/bash" "${steamShutdown}"]
            ];
          }
        ];

        # Per-game tiles straight in Moonlight: launch titles directly instead
        # of navigating Big Picture on touch. Upstream default scanner with
        # NixOS paths; same single-instance shutdown guard as above.
        application_scanner = [
          {
            type = "steam";
            library = "$HOME/.local/share/Steam";
            command = [
              "/run/current-system/sw/bin/steam"
              "-bigpicture"
              "steam://rungameid/{game_id}"
            ];
            stdout = "journal";
            stderr = "journal";
            pre_command = [
              ["${pkgs.bash}/bin/bash" "${steamShutdown}"]
            ];
          }
        ];
      };
    };

    # Membership scopes the shipped polkit rule that lets Moonshine inhibit
    # host sleep for the duration of a stream; without it streaming works but
    # the host may suspend mid-session.
    users.users.${cfg.user}.extraGroups = ["moonshine"];
  };
}
