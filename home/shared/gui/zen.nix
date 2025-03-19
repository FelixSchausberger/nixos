{
  config,
  inputs,
  pkgs,
  ...
}: let
  # Create a wrapper script for zen-browser with Wayland enabled
  zenWithWayland = pkgs.symlinkJoin {
    name = "zen-browser-wayland";
    paths = [inputs.zen-browser.packages."${pkgs.system}".twilight];
    buildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/zen \
        --set MOZ_ENABLE_WAYLAND 1
    '';
  };
in {
  imports = [
    (inputs.impermanence + "/home-manager.nix")
  ];

  home.packages = [zenWithWayland];

  home.persistence."/per/home/${config.home.username}" = {
    directories = [
      {
        directory = ".zen";
        # method = "symlink";
      }
    ];
  };
}
