# Test: power-relay module on m920q
{flake, ...}: let
  inherit (flake.nixosConfigurations.m920q) config;
  relay = config.modules.system.homelab.powerRelay;
in {
  power_relay_enabled = relay.enable;
  power_relay_port = relay.port;
  power_relay_bind_address = relay.bindAddress;
  power_relay_mac = relay.macAddress;
  power_relay_broadcast = relay.broadcastAddress;
  power_relay_topic = relay.ntfyTopic;
  power_relay_tokenless = relay.token == null;
  power_relay_service_after = config.systemd.services.power-relay.after;
  # The relay satisfies its ports via Tailscale-only binding; assert no
  # firewall row exists for them so the gate cannot silently reappear.
  power_relay_firewall_allowed_tcp = config.networking.firewall.allowedTCPPorts;
}
