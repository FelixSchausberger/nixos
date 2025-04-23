{
  config,
  hostName,
  inputs,
  ...
}: let
  # Use pipe operator to create derived paths more functionally
  getPath = base: suffix: "${base}/${suffix}";
  data =
    config.xdg.dataHome
    |> getPath "data"
    |> (path: "${path}/wine");

  conf =
    config.xdg.configHome
    |> getPath "config"
    |> (path: {
      less = {
        history = "${path}/less/history";
        lesskey = "${path}/less/lesskey";
      };
    });

  cache =
    config.xdg.cacheHome
    |> getPath "cache"
    |> (path: "${path}/less/history");

  username = inputs.self.lib.user;
in {
  imports = [
    inputs.nix-index-db.hmModules.nix-index
    (inputs.impermanence + "/home-manager.nix")
  ];

  home = {
    homeDirectory = "/home/${username}";
    username = "${username}";

    sessionVariables = {
      XDG_RUNTIME_DIR = "/run/user/$UID";

      # Clean up home directory using pipe operator for transformation
      LESSHISTFILE = conf.less.history;
      LESSKEY = conf.less.lesskey;

      WINEPREFIX = data;
      XAUTHORITY = "$XDG_RUNTIME_DIR/Xauthority";

      EDITOR = "hx";
      DIRENV_LOG_FORMAT = "";

      # Auto-run programs using nix-index-database
      NIX_AUTO_RUN = "1";
    };

    # Specify Home Manager release version
    stateVersion = "25.05";
  };

  # Let HM manage itself when in standalone mode
  programs.home-manager.enable = true;

  home.persistence."/per/home/${config.home.username}" = {
    allowOther = true;
    removePrefixDirectory = false;
  };
}
