{cosmicLib, ...}: {
  programs.cosmic-files = {
    enable = true;

    settings = {
      app_theme = cosmicLib.cosmic.mkRON "enum" "System";
      desktop = {
        show_content = false;
        show_mounted_drives = false;
        show_trash = false;
      };
      favorites = [
        (cosmicLib.cosmic.mkRON "enum" "Home")
        # (cosmicLib.cosmic.mkRON "enum" "Documents")
        (cosmicLib.cosmic.mkRON "enum" "Downloads")
        # (cosmicLib.cosmic.mkRON "enum" "Music")
        # (cosmicLib.cosmic.mkRON "enum" "Pictures")
        # (cosmicLib.cosmic.mkRON "enum" "Videos")
        # {
        #   __type = "tuple_enum";
        #   variant = "Path";
        #   values = "/per/etc/nixos";
        # }
      ];

      show_details = true;
      tab = {
        folders_first = true;
        icon_sizes = {
          grid = 100;
          list = 100;
        };
        show_hidden = true;
        view = cosmicLib.cosmic.mkRON "enum" "List";
      };
    };
  };
}
