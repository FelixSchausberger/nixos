{
  config,
  inputs,
  ...
}: let
  # Create derived paths more functionally
  getPath = base: suffix: "${base}/${suffix}";
  dataPath = getPath config.xdg.dataHome "data";
  data = "${dataPath}/wine";

  configPath = getPath config.xdg.configHome "config";
  conf = {
    less = {
      history = "${configPath}/less/history";
      lesskey = "${configPath}/less/lesskey";
    };
  };

  username = inputs.self.lib.user;
  inherit (inputs.self.lib) defaults;
in {
  imports = [
    inputs.nix-index-db.homeModules.nix-index
    ./persistence.nix
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
    stateVersion = defaults.system.version;
  };
}
