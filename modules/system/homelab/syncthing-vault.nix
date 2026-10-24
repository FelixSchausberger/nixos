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

  # The ignore list is a per-device artifact: the file sits in the synced
  # folder root and is never propagated to other devices
  # (https://docs.syncthing.net/users/ignoring.html), so Nix owns it as a
  # symlink rule (see the tmpfiles rule below). The same churn files the
  # Nextcloud desktop clients exclude through <vault>/.sync-exclude.lst; the
  # two lists must agree, or whichever client sees a change resyncs it behind
  # the other. The phone carries its own matching ignore entries.
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
      default = "tcp://100.77.207.10:22000";
      description = "Static address the server uses to reach the phone";
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
        devices = lib.optionalAttrs (cfg.phoneDeviceId != null) {
          phone = {
            id = cfg.phoneDeviceId;
            addresses = [cfg.phoneAddress];
            # Folder shares must be accepted deliberately on the phone.
            autoAcceptFolders = false;
          };
        };

        folders = {
          "obsidian-vault" = {
            label = "Obsidian vault";
            path = defaults.paths.obsidianVault;
            type = "sendreceive";
            devices = lib.optionals (cfg.phoneDeviceId != null) ["phone"];
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

    # L+ (symlink), not f+: on this systemd version f+ writes its argument
    # as literal content, and ignore patterns span lines. The symlink target
    # is a read-only store path, which is safe here: Syncthing only reads the
    # file, it is a per-device artifact not synced anywhere, and the Nextcloud
    # scan only resolves it to a few small text bytes if it syncs it through.
    systemd.tmpfiles.rules = [
      "L+ ${defaults.paths.obsidianVault}/.stignore - - - - ${stignore}"
    ];

    # Sync traffic is tailnet-only: the phone runs Tailscale, so the P2P
    # listener never has to be reachable on the LAN or the internet.
    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [22000];
      allowedUDPPorts = [22000];
    };
  };
}
