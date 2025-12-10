{
  rustPlatform,
  fetchFromGitHub,
  lib,
  pkg-config,
  openssl,
  perl,
}:
rustPlatform.buildRustPackage rec {
  pname = "lumen";
  version = "main";

  src = fetchFromGitHub {
    owner = "jnsahaj";
    repo = "lumen";
    rev = "main";
    sha256 = "sha256-DElM5gwipT82puD7w5KMxG3PGiwozJ2VVXtwwPbwV5g=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  nativeBuildInputs = [pkg-config perl];
  buildInputs = [openssl];

  doCheck = false; # Tests require git repository environment

  meta = with lib; {
    description = "Instant AI Git Commit message";
    homepage = "https://github.com/jnsahaj/lumen";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
