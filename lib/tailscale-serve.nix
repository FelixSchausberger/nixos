# One Tailscale Serve oneshot: terminate TLS on the node certificate and
# forward to a loopback upstream. Shared by the vaultwarden, zellij-web,
# opencode-web, homepage and prometheus serve units, which differ only in the
# port pair and the backing unit their upstream needs.
#
# `tailscale serve` requires the tailnet to be usable, and ordering after
# tailscaled.service covers only process start, not backend connectivity: a
# cold boot can leave the LAN without carrier for minutes, during which
# tailscaled reports NoState and the setup script fails. The unit therefore
# orders after tailscale-online.target, which the tailscale package backs with
# `tailscale wait` and which completes only once the backend is Running and
# the node has its tailnet address (m920q: 161s link delay on 2026-10-13
# wedged every serve unit).
#
# The retry budget bounds the wait: `tailscale wait` is cut off by this unit's
# TimeoutStartSec, and 20 attempts at 30s cover a slow boot while still
# exhausting on start-limit-hit when the failure is permanent, which is what
# keeps a real breakage visible to `systemctl is-failed` and vitals. The unit
# is green only once `tailscale serve` has succeeded.
{pkgs}: {
  # systemd unit name, e.g. "tailscale-serve-homepage"; also names the setup
  # script in the store.
  name,
  description,
  # HTTPS port served on the node certificate, and the loopback port the
  # upstream listens on.
  httpsPort,
  upstreamPort,
  upstreamHost ? "127.0.0.1",
  # Backing units beyond tailscaled.service that the upstream needs up first.
  after ? [],
  wants ? [],
}: {
  inherit description;
  after = ["tailscale-online.target"] ++ after;
  wants = ["tailscale-online.target"] ++ wants;
  wantedBy = ["multi-user.target"];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    TimeoutStartSec = 30;
    Restart = "on-failure";
    RestartSec = 30;
    ExecStart = pkgs.writeShellScript "${name}-setup" ''
      ${pkgs.tailscale}/bin/tailscale serve --bg \
        --https ${toString httpsPort} \
        http://${upstreamHost}:${toString upstreamPort}
    '';
  };
  # Re-serve whenever tailscaled comes back up.
  upholds = ["tailscaled.service"];
  unitConfig.StartLimitBurst = 20;
  unitConfig.StartLimitIntervalSec = 1800;
}
