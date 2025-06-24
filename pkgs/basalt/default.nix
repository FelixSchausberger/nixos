{pkgs ? import <nixpkgs> {}}:
pkgs.rustPlatform.buildRustPackage rec {
  pname = "basalt";
  version = "unstable-2024-10-01";

  src = pkgs.fetchFromGitHub {
    owner = "erikjuhani";
    repo = "basalt";
    rev = "main";
    sha256 = "sha256-omvMeQm2pq0fmvpLwa66VjwiuTG2zdkJEakfm5Zw9WQ=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  # Don't override installPhase, use postInstall instead
  postInstall = ''
        # Create config directory
        mkdir -p $out/share/basalt/config

        # Copy your existing obsidian.json
        cp ${./config/obsidian.json} $out/share/basalt/config/obsidian.json

        # Create wrapper script
        mv $out/bin/basalt $out/bin/.basalt-unwrapped

        cat > $out/bin/basalt <<EOF
    #!/usr/bin/env bash
    set -eu

    # Create temporary config directory
    tmp_config=\$(mktemp -d)
    trap "rm -rf '\$tmp_config'" EXIT

    # Set up config directory
    mkdir -p "\$tmp_config/.config/obsidian"
    cp "$out/share/basalt/config/obsidian.json" "\$tmp_config/.config/obsidian/obsidian.json"

    # Use XDG_CONFIG_HOME to point to our temporary config
    export XDG_CONFIG_HOME="\$tmp_config/.config"

    # Run the actual basalt binary
    exec "$out/bin/.basalt-unwrapped" "\$@"
    EOF

        chmod +x $out/bin/basalt
  '';

  meta = with pkgs.lib; {
    description = "TUI application to manage Obsidian notes from the terminal";
    homepage = "https://github.com/erikjuhani/basalt";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
