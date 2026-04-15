{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: let
  cfg = config.ai-assistants.opencode.openchamber;
  inherit (pkgs) stdenv;
  inherit (pkgs) nodejs_22;
  inherit (pkgs) git;
  inherit (pkgs) openssh;
  inherit (pkgs) cacert;
  # Wrap upstream openchamber to add runtime npm deps (express, etc.)
  openchamberPkg = stdenv.mkDerivation {
    pname = "openchamber-fixed";
    version = "1.8.7";
    src = inputs.openchamber-nix.packages.${pkgs.stdenv.hostPlatform.system}.openchamber;
    nativeBuildInputs = [nodejs_22 pkgs.makeWrapper];
    installPhase = ''
      mkdir -p $out/lib
      cp -r $src/lib/node_modules/@openchamber/web $out/lib/openchamber
      mkdir -p $out/bin
      cp -r $src/bin/* $out/bin/
      mkdir -p $out/share
      cp -r $src/share/* $out/share/
      chmod -R u+w $out
      chmod +x $out/lib/openchamber/bin/cli.js
    '';
    dontBuild = true;
    postFixup = ''
      # Already wrapped by upstream, but add nodejs to PATH
      wrapProgram $out/bin/openchamber \
        --prefix PATH : ${lib.makeBinPath [git openssh]} \
        --set NODE_EXTRA_CA_CERTS "${cacert}/etc/ssl/certs/ca-bundle.crt"
    '';
  };
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
        Type = "forking";
        ExecStart = "${openchamberPkg}/bin/openchamber ${lib.concatStringsSep " " args}";
        Restart = "on-failure";
        RestartSec = "10s";
        Environment = [
          "PATH=${lib.makeBinPath [pkgs.cloudflared]}:\${PATH}"
          "OPENCODE_HOST=http://localhost:4096"
          "OPENCODE_SKIP_START=true"
        ];
      };

      Install = lib.mkIf cfg.autoStart {
        WantedBy = ["default.target"];
      };
    };
  };
}
