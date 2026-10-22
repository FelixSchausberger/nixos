{
  inputs,
  lib,
  ...
}: {
  options.modules.home.tui.vault = {
    # Terminal tooling reaches the vault through this path. On the mount
    # host (modules/system/homelab/vault-mount.nix) the system module
    # overrides it to the WebDAV mount point; the fallback is the Nextcloud
    # external-storage directory that is the vault's canonical store.
    path = lib.mkOption {
      type = lib.types.str;
      default = inputs.self.lib.defaults.paths.obsidianVault;
      description = "Path terminal tooling uses to reach the Obsidian vault";
    };
  };
}
