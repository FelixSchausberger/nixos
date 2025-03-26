{pkgs, ...}: {
  home.packages = with pkgs; [
    dprint
    # dprint-plugins.dprint-plugin-markdown
  ];

  home.file.".dprint.json".text = ''
    {
      "markdown": {
        "lineWidth": 120
      },
      "excludes": [],
      "plugins": [
        "${pkgs.dprint-plugins.dprint-plugin-markdown}"
      ]
    }
  '';
}
