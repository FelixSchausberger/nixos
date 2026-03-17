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
    sha256 = "sha256-2XW6YAFEkXsKP4d3agLdpp2yt/bw/bd1Bi/qYeLj4G4=";
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
