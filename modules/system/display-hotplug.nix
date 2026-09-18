# Shared DRM-hotplug logic for on-demand user services.
#
# Only HDMI-A connectors are matched: the vkms virtual connector is permanently
# "connected" and would otherwise keep a session up forever. The debounced stop
# re-reads the CURRENT state after a window instead of trusting the triggering
# event, so a reconnect during the window keeps the session while a genuine loss
# stops it.
{pkgs}: rec {
  displayConnected = "grep -qsx connected /sys/class/drm/*-HDMI-A-*/status";

  # Start on connect, debounced stop on disconnect. The handlers run as root, so
  # they reach the user manager through machined (`-M user@`).
  hotplugScript = {
    user,
    startUnit,
    stopUnit,
  }: ''
    if ${displayConnected}; then
      exec ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start ${startUnit}
    fi
    # Projector warm-up bounces HPD (~68s on m920q), which would kill a healthy
    # session if acted on from a single read.
    sleep 45
    if ! ${displayConnected}; then
      exec ${pkgs.systemd}/bin/systemctl --user -M ${user}@ stop ${stopUnit}
    fi
  '';

  # A connector already present at boot may not emit a HOTPLUG change event,
  # so start once at boot when a display is connected. Best effort by design:
  # the boot unit is a wanted oneshot that switch-to-configuration re-runs, so
  # a failed start must not fail the unit — a failed unit aborts every
  # subsequent activation with exit 4.
  startScript = {
    user,
    startUnit,
  }: ''
    if ${displayConnected}; then
      if ! ${pkgs.systemd}/bin/systemctl --user -M ${user}@ start ${startUnit}; then
        echo "session-on-demand: failed to start ${startUnit}, retrying on next hotplug" >&2
      fi
    fi
  '';
}
