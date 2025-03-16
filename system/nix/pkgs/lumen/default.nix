{
  rustPlatform,
  fetchFromGitHub,
  lib,
  pkg-config,
  openssl,
}:
rustPlatform.buildRustPackage rec {
  pname = "lumen";
  version = "main";

  src = fetchFromGitHub {
    owner = "jnsahaj";
    repo = "lumen";
    rev = "main";
    sha256 = "sha256-nwnNCFDi+cQdbrOeoFMunbTgbxVw56h6pgl20Q3zM4E=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
  };

  nativeBuildInputs = [pkg-config];
  buildInputs = [openssl];

  meta = with lib; {
    description = "A Rust-based terminal multiplexer";
    homepage = "https://github.com/jnsahaj/lumen";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
