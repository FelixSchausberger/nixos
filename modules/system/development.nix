{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    # C env
    gcc
    gnumake

    # Javascript
    nodejs
    # nodejs_23

    # Python
    jq
    python3

    # GitHub Actions local runner
    act

    # Language Servers
    nodePackages.bash-language-server # Bash
    clang-tools # C/C++
    marksman # Markdown
    nixd # Nix
    python311Packages.python-lsp-server # Python
    taplo # TOML
    yaml-language-server # YAML
  ];
}
