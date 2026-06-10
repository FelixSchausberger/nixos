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
    rev = "6053b4ef3bc341332809ebfc712964cdeca902e6"; # main as of 2026-04-07
    sha256 = "sha256-ILAVTEo8t9+4QkIKJNPxMP7U3fSX2j3kqi9W99BdRB4=";
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
