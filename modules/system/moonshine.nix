{
  config,
  lib,
  ...
}: let
  cfg = config.modules.system.moonshine;
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

      # eno1 for LAN clients, tailscale0 for remote Moonlight sessions.
      # The nixpkgs module replaces the old flake's global openFirewall;
      # mkDefault lets consumers retarget other interface names (VM tests).
      firewallInterfaces = lib.mkDefault ["eno1" "tailscale0"];

      settings = {
        name = "Moonshine";
        application = [
          {
            title = "Steam";
            command = [
              "/run/current-system/sw/bin/steam"
              "steam://open/bigpicture"
            ];
          }
        ];
      };
    };
  };
}
