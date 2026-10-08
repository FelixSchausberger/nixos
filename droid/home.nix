# Home Manager profile for the phone. Deliberately self-contained: the fleet's
# modules/home tree is NixOS- and WSL-coupled (sops secrets, systemd units,
# WSL-patched fish plugins), so the phone reuses only the portable shell leaves
# and declares its own fish, ssh and git configuration. That keeps the phone's
# user environment declarative like the rest of the fleet without pulling the
# NixOS module graph onto Android.
{
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) defaults personalInfo;
in {
  imports = [
    ../modules/home/shells/zoxide.nix
    ../modules/home/shells/direnv.nix
    ../modules/home/shells/starship.nix
  ];

  home.stateVersion = defaults.system.version;
  # nixpkgs and Home Manager both track unstable; skip the release mismatch
  # warning, same as the fleet's shared Home Manager modules.
  home.enableNixpkgsReleaseCheck = false;

  programs = {
    fish.enable = true;

    # Host aliases come from the fleet registry so `ssh m920q` works on the
    # phone, whose own account is nix-on-droid (a bare `ssh m920q` would try
    # nix-on-droid@m920q and fail). Host keys are per device and generated on
    # the phone; only the public key belongs in the repo
    # (system/core/users.nix).
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings =
        {
          "*" = {
            ServerAliveInterval = 60;
            ServerAliveCountMax = 3;
            AddKeysToAgent = "yes";
            IdentitiesOnly = "yes";
          };
          "github.com" = {
            HostName = "ssh.github.com";
            Port = 443;
            User = "git";
          };
        }
        // lib.genAttrs (lib.attrNames inputs.self.lib.hosts) (_: {
          User = defaults.system.user;
        });
    };

    git = {
      enable = true;
      settings = {
        user = {
          inherit (personalInfo) name;
          # personalInfo.email is a runtime sops secret (private/email) and is
          # not available in the phone's proot environment; this address is
          # already public in the authorized-keys comments in
          # system/core/users.nix.
          email = "fel.schausberger@gmail.com";
        };
        init.defaultBranch = "main";
      };
    };

    jujutsu = {
      enable = true;
      settings.user = {
        inherit (personalInfo) name;
        email = "fel.schausberger@gmail.com";
      };
    };
  };
}
