{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    obsidian
  ];

  home.persistence."/per/home/${config.home.username}" = {
    directories = [
      {
        directory = ".config/obsidian";
      }
    ];
  };
}
