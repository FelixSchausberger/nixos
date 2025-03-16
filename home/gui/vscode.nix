{
  config,
  pkgs,
  ...
}: {
  programs.vscode = {
    enable = true;

    # https://search.nixos.org/packages?type=packages&query=vscode-extensions
    profiles.default.extensions = with pkgs.vscode-extensions; [
      kamadorueda.alejandra
      ms-python.black-formatter
      llvm-vs-code-extensions.vscode-clangd
      bbenoist.nix
      tomoki1207.pdf
      esbenp.prettier-vscode
      rust-lang.rust-analyzer
      # nvarner.typst-lsp
      redhat.vscode-yaml
    ];
  };

  home.persistence."/per/home/${config.home.username}" = {
    directories = [
      {
        directory = ".config/Code/";
      }
    ];
  };
}
