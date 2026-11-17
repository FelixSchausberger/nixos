# Cfait: terminal CalDAV task manager for the homelab session.
#
# Tasks are synced straight from Nextcloud's VTODO collections, so this module
# replaces the vdirsyncer/todoman task pair that used to live in pim.nix;
# chroncal handles events. The config is seeded once and then owned by cfait
# (it rewrites settings in place), so it must stay a regular file rather than
# a read-only store symlink.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  cfait = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.cfait;

  # Same app password and front door as the rest of the PIM stack: the secret
  # is read at sync time, never copied into the store.
  passwordCommand = "${pkgs.coreutils}/bin/cat ${
    config.sops.secrets."nextcloud/calendar-app-password".path
  }";

  seededConfig = pkgs.writeText "cfait-config.toml" ''
    url = "https://m920q.tailf2f0ca.ts.net/nextcloud/remote.php/dav"
    username = "admin"
    password_command = "${passwordCommand}"
    # Without this cfait stays in local-only mode and never contacts Nextcloud.
    enable_local_mode = false
  '';
in {
  home.packages = [cfait];

  # The upstream name is easy to forget; `todo` is the verb the user reaches
  # for. Aliases (not abbreviations) keep `todo` in shell history as typed.
  programs = {
    fish.shellAliases = lib.mkIf config.programs.fish.enable {
      todo = "cfait";
    };
    bash.shellAliases = lib.mkIf config.programs.bash.enable {
      todo = "cfait";
    };
  };

  home.activation.cfaitConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    target="$HOME/.config/cfait/config.toml"
    if [ ! -e "$target" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$target")"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0600 ${seededConfig} "$target"
    fi
  '';
}
