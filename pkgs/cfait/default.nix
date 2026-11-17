{
  lib,
  rustPlatform,
  fetchFromGitHub,
  aws-lc,
  oniguruma,
  pkg-config,
  zstd,
}: let
  # Pinned to the rolling branch, not a tag: `password_command` (the only
  # headless-safe credential source, required on m920q where no keyring runs)
  # landed after v1.2.1. Move the pin to a release once one carries it.
  rev = "b4b7e3e1faee8cac436a8786d82ae05b2eff3422";
in
  rustPlatform.buildRustPackage {
    pname = "cfait";
    version = "1.2.1-unstable-2026-11-16";

    src = fetchFromGitHub {
      owner = "trougnouf";
      repo = "cfait";
      inherit rev;
      hash = "sha256-c1UIzvbDPM4QHka1uuhVpdzXgybRyxfoEJeRlYGWEW8=";
    };

    cargoHash = "sha256-AIQVvhkenwkcdPWUz/zOXSQyRy15KFU41r/rRcmaQrM=";

    # rustls pulls aws-lc-rs; nixpkgs' cargo setup points aws-lc-sys at the
    # system library, so the headers and pkg-config file must be in scope.
    nativeBuildInputs = [pkg-config];
    buildInputs = [aws-lc oniguruma zstd];

    # Default features build the terminal UI; the iced GUI and the uniffi
    # Android bindings stay out of this derivation.
    doCheck = false;

    meta = with lib; {
      description = "CalDAV task manager with a terminal UI";
      homepage = "https://git.disroot.org/trougnouf/cfait";
      license = licenses.gpl3Plus;
      maintainers = [];
      platforms = platforms.linux;
      mainProgram = "cfait";
    };
  }
