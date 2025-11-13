# Shared security configuration for Wayland window managers
# Common security settings used by Hyprland and Niri
_: {
  security = {
    # PAM configuration for authentication
    pam.services = {
      # Enable GNOME Keyring for password management
      login.enableGnomeKeyring = true;
    };

    # Polkit for privilege escalation (required for system operations)
    polkit.enable = true;

    # RealtimeKit for real-time scheduling (required by PipeWire)
    rtkit.enable = true;
  };
}
