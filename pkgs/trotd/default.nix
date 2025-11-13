{
  lib,
  rustPlatform,
  pkg-config,
  openssl,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage {
  pname = "trotd";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "FelixSchausberger";
    repo = "trotd";
    rev = "c1aee8be97d5d3e9f1c12cd3fe6a3680a8b0b1f4";
    hash = "sha256-63V6DuFypRL+NCOxS9uAYQPA3YzxdCIR7VenOMEUZSg=";
  };

  cargoHash = "sha256-dKcY9rQVx/RQ/jax6z4+r28b/KotutaApOBLEx0c9IE=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
  ];

  meta = with lib; {
    description = "Trending repositories of the day - minimal MOTD CLI";
    longDescription = ''
      git-trending displays trending repositories from GitHub, GitLab, and Gitea.
      Designed for MOTD integration with silent error handling and caching support.
      Use as 'git trending' command.
    '';
    homepage = "https://github.com/FelixSchausberger/trotd";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "git-trending";
  };
}
