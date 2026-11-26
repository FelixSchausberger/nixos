{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.homelab.syncthingVault;
  defaults = inputs.self.lib.defaults;
  user = defaults.system.user;

  # Unset until the Syncthing-Fork app is paired (see the option description).
  hasPhoneDeviceId = cfg.phoneDeviceId != null;

  # The ignore list is a per-device artifact: the file sits in the synced
  # folder root and is never propagated to other devices
  # (https://docs.syncthing.net/users/ignoring.html), so Nix owns it as a
  # regular file refreshed at activation (see the activation script below).
  # The same churn files the Nextcloud desktop clients exclude through
  # <vault>/.sync-exclude.lst; the two lists must agree, or whichever client
  # sees a change resyncs it behind the other. The phone carries its own
  # matching ignore entries.
  stignore = pkgs.writeText "obsidian-stignore" ''
    // Obsidian rewrites these on every app open; syncing them only makes conflicts
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json
    .obsidian/workspaces.json
    // The desktop and phone legitimately diverge in UI appearance, so these
    // stay per-device rather than churning conflicts at every app open
    .obsidian/appearance.json
    .obsidian/hotkeys.json
    // Conflict artifacts are per-device leftovers resolved by hand
    (?d)*.sync-conflict-*
    // Desktop-client artifact kept for the Nextcloud sync pairs; not for the phone
    .sync-exclude.lst
    // Obsidian trash: local-only until deleted
    (?d).trash
    // Syncthing's own folder marker
    (?d).stfolder
    (?d).stignore
  '';
in {
  options.modules.system.homelab.syncthingVault = {
    enable = lib.mkEnableOption "Syncthing as the phone's two-way vault sync";

    phoneDeviceId = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      # Syncthing device IDs are public certificates, not secrets, so a plain
      # option is fine. Set it from the Syncthing-Fork app once installed
      # (the ID is also printed under the "scan QR code" pairing flow).
      description = "Syncthing device ID of the phone; unset until the app is paired";
    };

    phoneAddress = lib.mkOption {
      type = lib.types.str;
      # Static tailnet address: discovery stays off (see settings.options), so
      # the server must reach the phone without any discovery service.
      default = "tcp://100.78.213.64:22000";
      description = "Static address the server uses to reach the phone";
    };

    whatsapp = {
      # WhatsApp runs in the owner profile, so the existing `phone` device
      # shares the folder; no second Syncthing node is involved.
      enable = lib.mkEnableOption "sharing the phone's WhatsApp local database backups with the server";

      path = lib.mkOption {
        type = lib.types.str;
        default = "/per/mnt/data/backups/whatsapp";
        description = "Receive-only folder for WhatsApp's local database backups";
      };

      keepDays = lib.mkOption {
        type = lib.types.ints.positive;
        default = 30;
        description = "Days of staggered versions to keep for each backup file";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # The sync runs as the canonical vault owner so its writes keep the same
    # shape as a shell edit: owner stays schausberger, and the Nextcloud
    # external-storage ACLs (modules/system/homelab/nextcloud.nix tmpfiles)
    # already grant the nextcloud user r+w over owner-created files.
    services.syncthing = {
      enable = true;
      inherit user;
      group = "users";
      # Only the declared folder is managed; database lives under the
      # persistent /home dataset (hosts/m920q/disko.nix) so device keys and
      # the index survive reboots without extra persistence rules.
      dataDir = "${defaults.paths.homeDir}/.local/share";
      configDir = "${defaults.paths.homeDir}/.config/syncthing";

      settings = {
        devices = lib.optionalAttrs hasPhoneDeviceId {
          phone = {
            id = cfg.phoneDeviceId;
            addresses = [cfg.phoneAddress];
            # Folder shares must be accepted deliberately on the phone.
            autoAcceptFolders = false;
          };
        };

        folders =
          {
            "obsidian-vault" = {
              label = "Obsidian vault";
              path = defaults.paths.obsidianVault;
              type = "sendreceive";
              devices = lib.optionals hasPhoneDeviceId ["phone"];
            };
          }
          // lib.optionalAttrs (cfg.whatsapp.enable && hasPhoneDeviceId) {
            "whatsapp-backups" = {
              label = "WhatsApp local backups";
              path = cfg.whatsapp.path;
              # The phone is the only writer; the server keeps the history.
              type = "receiveonly";
              devices = ["phone"];
              # WhatsApp overwrites the database on every backup, so without
              # versioning the previous backup is gone the moment a new one
              # lands. Staggered versions keep a month of them.
              versioning = {
                type = "staggered";
                params = {
                  cleanupIntervalS = "3600";
                  maxAge = toString (cfg.whatsapp.keepDays * 86400);
                };
              };
            };
          };

        options = {
          # Discovery and relays are off: the tailnet already provides both
          # name resolution and connectivity, and the static device address
          # above covers the last hop. This keeps every Syncthing port
          # private to the tailnet instead of probing for paths through
          # NATs and relays.
          globalAnnounceEnabled = false;
          localAnnounceEnabled = false;
          relaysEnabled = false;
        };

        gui = {
          address = "127.0.0.1:8384";
        };
      };

      # Relay/default-port plumbing is bypassed on purpose: the firewall rule
      # below scopes sync traffic to tailscale0, and openDefaultPorts would
      # open the same ports on every interface.
      openDefaultPorts = false;
    };

    # Syncthing creates a missing folder itself, but the directory then
    # inherits the service umask. Pin the mode and owner so the backups stay
    # closed to other local users while the share group keeps access.
    systemd.tmpfiles.rules = lib.optionals cfg.whatsapp.enable [
      "d ${cfg.whatsapp.path} 0750 ${user} sambashare -"
    ];

    # A regular file, not a symlink into the store: the vault is also a
    # Nextcloud external-storage mount, and Nextcloud rejects any symlink that
    # resolves outside the mount's datadir, logging an error on every scan for
    # a link into /nix/store. tmpfiles cannot help here: f+ refuses to follow
    # or replace a symlink and C only creates missing paths, so the activation
    # script replaces the path and installs the generated content as an
    # ordinary file.
    system.activationScripts.syncthing-stignore = ''
      if [ -L ${defaults.paths.obsidianVault}/.stignore ] || \
         ! ${pkgs.diffutils}/bin/cmp -s ${stignore} ${defaults.paths.obsidianVault}/.stignore; then
        ${pkgs.coreutils}/bin/rm -f ${defaults.paths.obsidianVault}/.stignore
        ${pkgs.coreutils}/bin/install -m 0644 ${stignore} ${defaults.paths.obsidianVault}/.stignore
      fi
    '';

    # Sync traffic is tailnet-only: the phone runs Tailscale, so the P2P
    # listener never has to be reachable on the LAN or the internet.
    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [22000];
      allowedUDPPorts = [22000];
    };
  };
}
