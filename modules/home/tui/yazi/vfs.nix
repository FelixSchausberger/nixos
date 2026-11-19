{
  config,
  hostName,
  inputs,
  lib,
  ...
}: let
  inherit (inputs.self.lib) hosts user;

  # Generate the fleet list from the host registry so VFS entries do not
  # drift when a host is added. Tailnet addresses are reachable on and off
  # the LAN, and the sops-provided SSH key has no passphrase, so key_file
  # authentication does not depend on a running agent.
  remoteHosts = lib.filterAttrs (name: h: name != hostName && (h ? tailnetIp || h ? ip)) hosts;
in {
  programs.yazi.vfs.sftp =
    lib.mapAttrs (_name: h: {
      host = h.tailnetIp or h.ip;
      inherit user;
      port = 22;
      key_file = "${config.home.homeDirectory}/.ssh/id_ed25519";
    })
    remoteHosts;
}
