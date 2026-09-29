{pkgs, ...}: {
  imports = [
    ./languages.nix # Language servers, formatters, and per-language config shared by Helix and Neovim
    ./dprint.nix # dprint formatting platform used by both editors' markdown/toml formatters
  ];

  # Neovim is the default editor. nvedit reuses the Neovim instance that owns
  # the current terminal ($NVIM is set by :terminal) and blocks until the
  # buffer is closed, so git, jj, zellij scrollback, and OpenCode all wait for
  # the edit to finish instead of nesting a second full-screen instance.
  # Everywhere else it starts a regular nvim from PATH.
  home.sessionVariables = {
    EDITOR = "nvedit";
    VISUAL = "nvedit";
  };

  home.file.".local/bin/nvedit" = {
    executable = true;
    text = ''
      #!${pkgs.bash}/bin/bash
      if [ -n "''${NVIM:-}" ]; then
        exec ${pkgs.neovim-remote}/bin/nvr --remote-wait "$@"
      fi
      exec nvim "$@"
    '';
  };
}
