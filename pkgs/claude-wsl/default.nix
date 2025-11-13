{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:
buildNpmPackage rec {
  pname = "claude-wsl";
  version = "1.2.6";

  src = fetchFromGitHub {
    owner = "fullstacktard";
    repo = "claude-wsl";
    rev = "bda7379e4e7010f0cc9e3ae3cdaa99f2623f0bfc"; # Latest commit with v1.2.6
    hash = "sha256-6pCSqkPEHyU4DTyUNVhUAYp8t1T40Gi00bLIHH8usro=";
  };

  npmDepsHash = "sha256-jmyTXJWGKTsayIeT5/tnKvZlM04XkR8yVlon844sJCA=";

  # No build script - package consists of scripts only
  dontNpmBuild = true;

  # Don't run the postinstall script that modifies .bashrc
  # We'll handle integration declaratively through NixOS modules
  postPatch = ''
    # Remove postinstall script from package.json if it exists
    substituteInPlace package.json \
      --replace-warn '"postinstall":' '"postinstall-disabled":'
  '';

  # Install notification scripts to share directory
  # These will be symlinked to ~/.local/share/claude-wsl/ by home-manager
  postInstall = ''
    mkdir -p $out/share/claude-wsl
    cp -r templates/notify/* $out/share/claude-wsl/
    chmod +x $out/share/claude-wsl/*.sh
  '';

  # Package metadata
  meta = with lib; {
    description = "Visual notifications for Claude Code in WSL";
    homepage = "https://github.com/fullstacktard/claude-wsl";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
  };
}
