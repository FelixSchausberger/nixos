{cosmicLib, ...}: {
  programs.cosmic-files = {
    enable = true;

    settings = {
      #   app_theme = cosmicLib.cosmic.mkRon "enum" "System";
      #   desktop = {
      #     show_content = true;
      #     show_mounted_drives = false;
      #     show_trash = false;
      #   };
      favorites = [
        (cosmicLib.cosmic.mkRon "enum" "Home")
        #   (cosmicLib.cosmic.mkRon "enum" "Documents")
        (cosmicLib.cosmic.mkRon "enum" "Downloads")
        #   (cosmicLib.cosmic.mkRon "enum" "Music")
        #   (cosmicLib.cosmic.mkRon "enum" "Pictures")
        #   (cosmicLib.cosmic.mkRon "enum" "Videos")
      ];
      #   show_details = false;
      #   tab = {
      #     folders_first = true;
      #     icon_sizes = {
      #       grid = 100;
      #       list = 100;
      #     };
      #     show_hidden = true;
      #     view = inputs.cosmicLib.cosmic.mkRon "enum" "List";
      #   };
    };
  };
}
