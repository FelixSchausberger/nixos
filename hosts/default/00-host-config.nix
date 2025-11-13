{
  lib,
  config,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) defaults;
  cfg = config.hostConfig;
in {
  options.hostConfig = lib.mkOption {
    type = lib.types.submodule {
      options = {
        hostName = lib.mkOption {
          type = lib.types.str;
          description = "The hostname for this system";
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = defaults.system.user;
          description = "Primary user for this system";
        };

        wm = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [];
          description = "List of window managers/desktop environments to enable";
        };

        isGui = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether this host enables a graphical session";
        };

        system = lib.mkOption {
          type = lib.types.str;
          default = defaults.system.architecture;
          description = "System architecture";
        };

        autoLogin = lib.mkOption {
          type = lib.types.nullOr (lib.types.submodule {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = "Enable automatic login";
              };

              user = lib.mkOption {
                type = lib.types.str;
                description = "User to automatically log in";
              };
            };
          });
          default = null;
          description = "Auto-login configuration";
        };
      };
    };
    description = "Host-specific configuration options";
  };

  config = {
    _module.args = {inherit (config) hostConfig;};
    networking.hostName = cfg.hostName;
  };
}
