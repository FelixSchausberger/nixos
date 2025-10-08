{
  lib,
  fetchFromGitHub,
  rustPlatform,
  pkg-config,
  wayland,
  wayland-protocols,
}:
rustPlatform.buildRustPackage {
  pname = "vigiland";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "Jappie3";
    repo = "vigiland";
    rev = "62d0d6be2e19690c88e627eff76161ba41adbf97";
    hash = "sha256-Y/MUjPWd09YGUWBIXSjQGAcRmgKLcHAMYNjWvDTiV2c=";
  };

  cargoHash = "sha256-gIFD4Ey2PlWi+fIsiplCxBVn2+ueECmFskJLdKOucc8=";

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    wayland
    wayland-protocols
  ];

  # Vigiland requires a Wayland compositor with idle-inhibit-unstable-v1 protocol support
  meta = with lib; {
    description = "Wayland idle inhibitor to keep your screen awake";
    longDescription = ''
      Vigiland is a simple idle inhibitor for Wayland compositors that implement
      the idle-inhibit-unstable-v1 protocol. It prevents the screen from going
      idle/sleeping while running.
    '';
    homepage = "https://github.com/Jappie3/vigiland";
    license = licenses.agpl3Only;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "vigiland";
  };
}
