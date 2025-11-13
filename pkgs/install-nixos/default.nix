{
  lib,
  stdenv,
  makeWrapper,
  bash,
  coreutils,
  util-linux,
  systemd,
  pciutils,
  gawk,
  gnugrep,
  glibc,
}:
stdenv.mkDerivation {
  pname = "install-nixos";
  version = "1.0.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  buildInputs = [bash];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp install-nixos $out/bin/install-nixos
    chmod +x $out/bin/install-nixos

    # Wrap with required dependencies in PATH
    wrapProgram $out/bin/install-nixos \
      --prefix PATH : ${lib.makeBinPath [
      coreutils
      util-linux
      systemd
      pciutils
      gawk
      gnugrep
      glibc
    ]}

    runHook postInstall
  '';

  meta = with lib; {
    description = "Interactive NixOS installation helper with automatic host detection";
    longDescription = ''
      install-nixos is a shell-agnostic installation script that:
      - Auto-detects hardware and suggests the appropriate NixOS host configuration
      - Provides interactive disk selection
      - Uses disko for declarative, reproducible partitioning
      - Supports both interactive and scripted (--yes) modes

      Works in the NixOS installer environment before any configuration is loaded.
    '';
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "install-nixos";
  };
}
