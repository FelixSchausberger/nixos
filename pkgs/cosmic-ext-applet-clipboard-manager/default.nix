{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  libcosmicAppHook,
  pkg-config,
  openssl,
  sqlite,
}:
rustPlatform.buildRustPackage {
  pname = "cosmic-ext-applet-clipboard-manager";
  version = "0.1.0-unstable-2026-11-16";

  src = fetchFromGitHub {
    owner = "cosmic-utils";
    repo = "clipboard-manager";
    rev = "0713b86bc1e6b821a32225b3701c79908b6019b3";
    hash = "sha256-AMOQIRbL2Qpr0/CeudmvrmwfuZsqYUEjYVbSwA9Cqro=";
  };

  useFetchCargoVendor = true;
  cargoHash = "sha256-ABo4fAtFCaIyNukOUZqHpBhR0fANkb/h7lz755LyRpA=";

  nativeBuildInputs = [
    libcosmicAppHook
    pkg-config
  ];

  buildInputs = [
    openssl
    sqlite
  ];

  # The applet ships a desktop entry, metainfo and symbolic icon next to the
  # binary; the panel resolves the entry and icon by app id.
  installPhase = ''
    runHook preInstall
    install -Dm755 target/${stdenv.hostPlatform.rust.cargoShortTarget}/release/cosmic-ext-applet-clipboard-manager \
      $out/bin/cosmic-ext-applet-clipboard-manager
    install -Dm644 res/desktop_entry.desktop \
      $out/share/applications/io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager.desktop
    install -Dm644 res/metainfo.xml \
      $out/share/metainfo/io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager.metainfo.xml
    install -Dm644 res/app_icon.svg \
      $out/share/icons/hicolor/scalable/apps/io.github.cosmic_utils.cosmic-ext-applet-clipboard-manager-symbolic.svg
    runHook postInstall
  '';

  meta = {
    description = "Clipboard manager applet for the COSMIC desktop";
    homepage = "https://github.com/cosmic-utils/clipboard-manager";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    mainProgram = "cosmic-ext-applet-clipboard-manager";
  };
}
