# Chroncal: terminal CalDAV calendar for the homelab session.
#
# Events are synced straight from Nextcloud's CalDAV collections, so this
# module replaces the vdirsyncer/khal pair that used to live in pim.nix; tasks
# stay in cfait (modules/home/tui/cfait.nix) and contacts in khard. The config
# is seeded once and then owned by chroncal (the TUI rewrites settings in
# place), so it must stay a regular file rather than a read-only store symlink.
#
# First run per host needs account discovery and an initial sync. This is a
# one-time network operation and deliberately not part of activation:
#   chroncal account add nextcloud \
#     --server https://m920q.tailf2f0ca.ts.net/nextcloud/remote.php/dav \
#     --username admin \
#     --password-cmd '<coreutils>/bin/cat <decrypted-secret-path>'
#   chroncal account calendars list nextcloud
#   chroncal account calendars set nextcloud --calendar personal \
#     --default personal --yes
# `account add` imports every usable VEVENT/VTODO/VJOURNAL collection, so
# prune VTODO collections: cfait must remain the only task writer. Keep the
# server-generated contact_birthdays calendar in the selection if birthday
# events are wanted; khal no longer renders them from BDAY fields.
{
  config,
  lib,
  pkgs,
  ...
}: let
  seededConfig = pkgs.writeText "chroncal-config.toml" ''
    [sync]
    # Record a conflict and keep the local edit instead of letting the
    # unattended timer silently adopt the server version.
    conflict_strategy = "prompt"
  '';
in {
  home.packages = [pkgs.chroncal];

  # `calendar` is the word the user reaches for. Not `cal`: that is
  # util-linux's month printer, and shadowing it would surprise every
  # non-calendar use. Aliases (not abbreviations) keep `calendar` in shell
  # history as typed, matching the cfait `todo` alias.
  programs = {
    fish.shellAliases = lib.mkIf config.programs.fish.enable {
      calendar = "chroncal";
    };
    bash.shellAliases = lib.mkIf config.programs.bash.enable {
      calendar = "chroncal";
    };
  };

  home.activation.chroncalConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
    target="$HOME/.config/chroncal/config.toml"
    if [ ! -e "$target" ]; then
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/mkdir -p "$(dirname "$target")"
      $DRY_RUN_CMD ${pkgs.coreutils}/bin/install -m 0600 ${seededConfig} "$target"
    fi
  '';

  # The timer owns the sync cadence. `chroncal service install` is not used:
  # it writes units into ~/.config/systemd/user behind Home Manager's back.
  systemd.user.services.chroncal-sync = {
    Unit.Description = "Sync chroncal calendars with CalDAV";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.chroncal}/bin/chroncal sync run";
    };
  };

  systemd.user.timers.chroncal-sync = {
    Unit.Description = "Periodic chroncal CalDAV sync";
    Timer = {
      OnCalendar = "*:0/15";
      Persistent = true;
    };
    Install.WantedBy = ["timers.target"];
  };
}
