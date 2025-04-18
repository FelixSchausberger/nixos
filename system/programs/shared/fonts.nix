{pkgs, ...}: {
  # Define a set of font packages using Nerd Fonts with FiraCode
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      # font-awesome
      # roboto
      # roboto-mono
      # source-serif-pro
    ];

    # fontconfig = {
    #   defaultFonts = {
    #     # monospace = [ "FiraCode Mono" ];
    #     # sansSerif = [ "FiraCode" ];
    #     monospace = ["Roboto Mono"];
    #     sansSerif = ["Roboto"];
    #     serif = ["Source Serif Pro"];
    #   };
    # };
  };
}
