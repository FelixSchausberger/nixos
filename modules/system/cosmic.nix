{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.nixos-cosmic.nixosModules.default
    "${inputs.impermanence}/nixos.nix"
  ];

  # services = {
  #   desktopManager.cosmic.enable = true;
  #   displayManager.cosmic-greeter.enable = true;
  #   # getty.autologinUser = inputs.self.lib.user;
  # };

  xdg.portal = {
    enable = true;
    config.common.default = "*";
    extraPortals = [pkgs.xdg-desktop-portal-cosmic];
  };

  environment = {
    cosmic.excludePackages = with pkgs; [
      cosmic-wallpapers
    ];

    # Allow auto-login
    # etc."greetd/cosmic-greeter.toml" = {
    #   source = pkgs.writeText "cosmic-greeter-config" ''
    #     [terminal]
    #     vt = "1"

    #     [general]
    #     service = "login"

    #     [default_session]
    #     command = "cosmic-comp systemd-cat -t cosmic-greeter cosmic-greeter"
    #     user = "cosmic-greeter"

    #     [initial_session]
    #     command = "cosmic-session"
    #     user = "${inputs.self.lib.user}"
    #   '';
    #   mode = "0644";
    # };

    persistence."/per" = {
      users.${inputs.self.lib.user} = {
        directories = [
          {
            directory = ".config/cosmic/";
          }
        ];
      };
    };

    sessionVariables = {
      # For the clipboard manager to work zwlr_data_control_manager_v1 protocol needs to be available
      COSMIC_DATA_CONTROL_ENABLED = 1;

      # Firefox fullscreen freezes comsic
      # Remove once https://github.com/pop-os/cosmic-comp/issues/713 is fixed
      COSMIC_DISABLE_DIRECT_SCANOUT = 1;
    };

    systemPackages = with pkgs; [
      cosmic-ext-applet-caffeine # Prevents your screen from going to sleep
      cosmic-ext-applet-clipboard-manager # Clipboard manager for COSMIC.
      cosmic-ext-applet-emoji-selector # Emoji Selector for COSMIC DE.
      cosmic-ext-applet-external-monitor-brightness # Change brightness of external monitors via DDC/CI protocol.
      # cosmic-applet-ollama # Applet for Ollama
      # cosmic-ext-applet-privacy-indicator # Privacy Indicator applet for COSMIC
      # cosmic-ext-applet-system-monitor # A highly configurable resource monitor applet for the COSMIC DE
      examine # A system information viewer for the COSMIC desktop.

      xdg-desktop-portal-cosmic # XDG Desktop Portal for the COSMIC Desktop Environment
      xdg-desktop-portal-wlr
    ];
  };

  # systemd = {
  #   packages = [pkgs.observatory];
  #   services.monitord.wantedBy = ["multi-user.target"];
  # };
}
