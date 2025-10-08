# Pure Nix function template for configuration utilities
{
  lib,
  pkgs,
  ...
}: let
  # Tool metadata
  name = "my-nix-function"; # CHANGE THIS
  version = "0.1.0";

  # Helper functions
  inherit
    (lib)
    mkOption
    types
    mkIf
    ;

  result = {
    # Main function - example: generate NixOS configuration
    generateConfig = {
      hostname,
      username,
      modules ? [],
    }: {
      imports = modules;

      networking.hostName = hostname;

      users.users.${username} = {
        isNormalUser = true;
        extraGroups = ["wheel" "networkmanager"];
      };

      # Add more default configuration here
      system.stateVersion = "25.11";
    };

    # Configuration validation function
    validateConfig = config: let
      errors =
        (lib.optional (!config ? networking.hostName) "hostname is required")
        ++ (lib.optional (!config ? users) "users configuration is required");
    in
      if errors == []
      then {
        success = true;
        inherit config;
      }
      else {
        success = false;
        inherit errors;
      };

    # Package builder function
    buildPackage = {
      name,
      src,
      buildInputs ? [],
      ...
    }:
      pkgs.stdenv.mkDerivation {
        inherit name src buildInputs;

        buildPhase = ''
          # TODO: Add build steps
          echo "Building ${name}..."
        '';

        installPhase = ''
          mkdir -p $out/bin
          # TODO: Install your built artifacts
          echo "Installing ${name}..."
        '';
      };

    # NixOS module generator
    mkModule = {
      name,
      config,
      options ? {},
    }: {
      options.services.${name} = mkOption {
        type = types.submodule {
          options =
            {
              enable = mkOption {
                type = types.bool;
                default = false;
                description = "Enable ${name} service";
              };
            }
            // options;
        };
        default = {};
        description = "Configuration for ${name}";
      };

      config = mkIf config.services.${name}.enable {
        # TODO: Add service configuration
      };
    };

    # File template generator
    generateFile = {
      template,
      substitutions ? {},
    }: let
      # Simple string substitution (for more complex cases, use pkgs.substituteAll)
      substitute = str: subs:
        lib.foldl' (
          acc: sub:
            builtins.replaceStrings ["{{${sub.name}}}"] [sub.value] acc
        )
        str (lib.mapAttrsToList (name: value: {inherit name value;}) subs);
    in
      substitute template substitutions;

    # System information collector
    getSystemInfo = {
      platform = pkgs.system;
      nixVersion = lib.version;
      availablePackages = builtins.length (builtins.attrNames pkgs);
    };

    # Configuration merger utility
    mergeConfigs = configs:
      lib.foldl' lib.recursiveUpdate {} configs;

    # Package set creator
    mkPackageSet = packageDefs:
      lib.mapAttrs (
        _name: def:
          if builtins.isFunction def
          then def pkgs
          else def
      )
      packageDefs;

    # Example usage functions (these use functions defined above)
    examples = let
      self = result; # Allow recursive reference
    in {
      # Generate a basic NixOS config
      basicConfig = self.generateConfig {
        hostname = "example-host";
        username = "alice";
        modules = [
          # Add additional modules here
        ];
      };

      # Create a simple package
      simplePackage = self.buildPackage {
        name = "example-tool";
        src = ./src;
        buildInputs = with pkgs; [bash];
      };

      # Generate a configuration file
      configFile = self.generateFile {
        template = ''
          # Generated configuration
          hostname = "{{hostname}}"
          user = "{{username}}"
          version = "{{version}}"
        '';
        substitutions = {
          hostname = "localhost";
          username = "user";
          version = "1.0";
        };
      };
    };

    # Meta information
    meta = {
      inherit name version;
      description = "Nix utility functions for system configuration";
      platforms = lib.platforms.all;
    };
  };
in
  result
