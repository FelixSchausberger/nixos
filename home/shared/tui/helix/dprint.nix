{pkgs, ...}: {
  home.packages = with pkgs; [
    dprint
  ];

  home.file.".dprint.json".text = ''
    {
      "markdown": {
        "lineWidth": 120
      },
      "excludes": [],
      "plugins": [
        "${pkgs.dprint-plugins.dprint-plugin-dockerfile}"
        "${pkgs.dprint-plugins.dprint-plugin-json}"
        "${pkgs.dprint-plugins.dprint-plugin-markdown}"
        "${pkgs.dprint-plugins.dprint-plugin-toml}"
      ]
    }
  '';
}
