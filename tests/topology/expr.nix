# Test: homelab topology package produces valid D2 and inventory
{flake, ...}: let
  inherit (flake.packages.x86_64-linux) homelab-topology;
in {
  d2_text_nonempty = homelab-topology.passthru.d2Text != "";
  d2_has_internet = builtins.match ".*internet:.*" homelab-topology.passthru.d2Text != null;
  d2_has_m920q = builtins.match ".*m920q:.*" homelab-topology.passthru.d2Text != null;
  d2_has_fritzbox = builtins.match ".*fritzbox:.*" homelab-topology.passthru.d2Text != null;
  d2_has_desktop = builtins.match ".*desktop:.*" homelab-topology.passthru.d2Text != null;
  d2_has_tailscale = builtins.match ".*tailscale:.*" homelab-topology.passthru.d2Text != null;
  enabled_service_count = builtins.length (builtins.attrNames homelab-topology.passthru.enabled);
  enabled_services = builtins.attrNames homelab-topology.passthru.enabled;
  has_immich = builtins.hasAttr "immich" homelab-topology.passthru.enabled;
  has_monitoring = builtins.hasAttr "monitoring" homelab-topology.passthru.enabled;
}
