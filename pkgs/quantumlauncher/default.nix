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
    version = "0.5.1";

    src = fetchFromGitHub {
      owner = "Mrmayman";
      repo = "quantumlauncher";
      rev = "v${version}";
      hash = "sha256-98KlD6O91Em02K+Hs9XPQ/ybYjMeEsoVUZpYpi8vkfc=";
    };

    cargoHash = "sha256-xCbTkU+aocl03LC5RD4I9kKyjw8kySj7BJwFFaf1iMQ=";

    # Skip doctests due to upstream test issues; 0.5.1 has no library target,
    # so --lib must not be requested here.
    cargoTestFlags = ["--bins"];

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
