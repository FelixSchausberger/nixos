# Public SSH keys authorized for the fleet user on every host, NixOS and the
# nix-on-droid phone alike. The private halves live in sops (NixOS) or are
# generated on the device (the phone's own key); only public keys belong here,
# so the phone's sshd can consume the same list the NixOS users module grants.
{
  authorizedKeys = [
    # m920q and the other NixOS hosts (sops secret private/id_ed25519).
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILb6i2hFXxCZFLxxkDHKzyoyNO7pZjH4B177Ia+zZuJw fel.schausberger@gmail.com"
    # The phone's own key, generated in the nix-on-droid environment.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOkv0EEQ9PF91cuKW5ZIQkFoSmSWMwgXlUEjWq4D7R43 pixel9a"
  ];
}
