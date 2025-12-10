{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  vulkan-loader,
  wayland,
  wayland-protocols,
  libxkbcommon,
  libGL,
  libx11,
  libxcursor,
  libxrandr,
  libxi,
}: let
  desktopItem = makeDesktopItem {
    name = "quantumlauncher";
    desktopName = "QuantumLauncher";
    genericName = "Minecraft Launcher";
    comment = "Simple, powerful Minecraft launcher built with Rust and Iced";
    exec = "quantum_launcher";
    icon = "minecraft-launcher";
    categories = ["Game" "Java"];
    terminal = false;
    startupNotify = true;
    type = "Application";
    keywords = ["minecraft" "game" "launcher" "mod" "forge" "fabric" "neoforge" "quilt" "optifine"];
  };
in
  rustPlatform.buildRustPackage rec {
    pname = "quantumlauncher";
    version = "0.4.2";

    src = fetchFromGitHub {
      owner = "Mrmayman";
      repo = "quantumlauncher";
      rev = "v${version}";
      hash = "sha256-9dMSFxSZTfyh3xkEYU0Xrak3n8K7ocaLI1OKI62fTMQ=";
    };

    cargoHash = "sha256-2v3/ROoA/Ri8BXhK+lr+4lhN2HHvjZ9ejZ2/EDw7r3w=";

    # Skip doctests due to upstream test issues
    cargoTestFlags = ["--bins" "--lib"];

    nativeBuildInputs = [
      pkg-config
      makeWrapper
      copyDesktopItems
    ];

    buildInputs = [
      vulkan-loader
      wayland
      wayland-protocols
      libxkbcommon
      libGL
      libx11
      libxcursor
      libxrandr
      libxi
    ];

    desktopItems = [desktopItem];

    postFixup = ''
      wrapProgram $out/bin/quantum_launcher \
        --suffix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs}
    '';

    meta = with lib; {
      description = "Simple, powerful Minecraft launcher built with Rust and Iced";
      longDescription = ''
        QuantumLauncher is a cross-platform Minecraft launcher built with Rust and
        the Iced GUI framework. Supports vanilla Minecraft, Fabric, Forge, NeoForge,
        Quilt, and OptiFine with integrated mod store functionality.
      '';
      homepage = "https://github.com/Mrmayman/quantumlauncher";
      license = licenses.gpl3Only;
      maintainers = [];
      platforms = platforms.linux;
      mainProgram = "quantum_launcher";
    };
  }
