{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  environment.systemPackages = with pkgs; [
    age # Modern encryption tool with small explicit keys
    ssh-to-age # Convert ssh private keys in ed25519 format to age keys
    sops # Simple and flexible tool for managing secrets
  ];

  sops = {
    age.sshKeyPaths = ["/home/${inputs.self.lib.user}/.ssh/id_ed25519"];
    defaultSopsFile = "${inputs.self}/secrets/secrets.json";
  };

  # Critical: Force sops-nix to decrypt BEFORE user accounts are created
  systemd.services.sops-nix = {
    before = ["systemd-user-sessions.service"];
    requiredBy = ["systemd-user-sessions.service"];
    unitConfig = {
      DefaultDependencies = "no"; # Start earlier in boot
    };
  };
}
