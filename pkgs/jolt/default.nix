{
  lib,
  rustPlatform,
  fetchFromGitHub,
  darwin,
  stdenv,
}:
rustPlatform.buildRustPackage rec {
  pname = "jolt";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "jordond";
    repo = "jolt";
    rev = "refs/heads/main";
    hash = "sha256-A8X06Y7Ujl2rN4+op6ixbWaL4Tx9Toj6+jSgRhRcDRM=";
  };

  cargoHash = "sha256-5SKyKTQXqcRsmvyHfq4i7RcGiL+3lENcEXU1FgTGsek=";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isDarwin [darwin.apple_sdk.frameworks.CoreFoundation];

  buildAndTestSubdir = "cli";
  cargoBuildFlags = ["--package" "jolt-tui"];

  doCheck = false;

  meta = with lib; {
    description = "Terminal-based battery and energy monitor for macOS and Linux";
    homepage = "https://getjolt.sh";
    license = licenses.mit;
    maintainers = with maintainers; [];
    mainProgram = "jolt";
    platforms = platforms.unix;
  };
}
