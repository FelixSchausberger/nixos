{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.ai-assistants.opencode.openchamber;
in {
  options.ai-assistants.opencode.openchamber = {
    enable = lib.mkEnableOption "OpenChamber systemd service with Cloudflare tunnel support";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Port for OpenChamber web interface";
    };

    enableCloudflare = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Cloudflare tunnel for remote access";
    };

    enableQrCode = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate QR code in service logs for easy mobile access";
    };

    password = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        UI password for authentication.
        WARNING: This will be stored in the Nix store. Consider using sops-nix for production.
        Leave empty to disable password protection (not recommended for Cloudflare tunnel).
      '';
    };

    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Auto-start service on login (adds to default.target)";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.openchamber = {
      Unit = {
        Description = "OpenChamber web interface for OpenCode";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };

      Service = let
        args =
          ["--port" "${toString cfg.port}"]
          ++ lib.optional cfg.enableCloudflare "--try-cf-tunnel"
          ++ lib.optional (cfg.enableCloudflare && cfg.enableQrCode) "--tunnel-qr"
          ++ lib.optional (cfg.password != "") "--ui-password ${cfg.password}";
      in {
        ExecStart = "${pkgs.openchamber}/bin/openchamber ${lib.concatStringsSep " " args}";
        Restart = "on-failure";
        RestartSec = "10s";
        # Ensure cloudflared is available in PATH
        Environment = ["PATH=${lib.makeBinPath [pkgs.cloudflared]}:\${PATH}"];
      };

      Install = lib.mkIf cfg.autoStart {
        WantedBy = ["default.target"];
      };
    };
  };
}
