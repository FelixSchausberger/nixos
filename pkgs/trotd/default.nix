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
    rev = "5fa146b5dbf55d005efc234b29611b0c9762990c";
    hash = "sha256-OQFy+1RXDhuPqp1AEzICPo5o+ufdKPBI/EMi7kgiRBI=";
  };

  cargoHash = "sha256-hkFQD/9yaKWxLVBIm1jiiwzb3yStz0I9cO2eG0VJq6o=";

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
