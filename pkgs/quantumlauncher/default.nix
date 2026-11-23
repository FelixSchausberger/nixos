{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  addDriverRunpath,
  vulkan-loader,
  wayland,
  wayland-protocols,
  libxkbcommon,
  libGL,
  libx11,
  libxcursor,
  libxrandr,
  libxi,
  nix-update-script,
}: let
  desktopItem = makeDesktopItem {
    # Desktop file and icon names follow the AppStream ID upstream ships in
    # assets/freedesktop/quantum-launcher.metainfo.xml, so the menu entry,
    # the metainfo and the icon resolve to one application.
    name = "io.github.Mrmayman.QuantumLauncher";
    desktopName = "Quantum Launcher";
    genericName = "Minecraft Launcher";
    comment = "Simple, powerful Minecraft launcher built with Rust and Iced";
    exec = "quantum_launcher";
    icon = "io.github.Mrmayman.QuantumLauncher";
    categories = ["Game" "Java"];
    terminal = false;
    startupNotify = true;
    prefersNonDefaultGPU = true;
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

    # Upstream commits the lock, so vendor the reviewed dependency set
    # instead of resolving from Cargo.toml at build time.
    cargoLock.lockFile = "${src}/Cargo.lock";

    # Skip doctests due to upstream test issues; 0.5.1 has no library target,
    # so --lib must not be requested here.
    cargoTestFlags = ["--bins"];

    nativeBuildInputs = [
      pkg-config
      makeWrapper
      copyDesktopItems
      # WINIT_UNIX_BACKEND loads libGL/libvulkan from the driver path, which
      # is not in the buildInputs closure.
      addDriverRunpath
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

    # The icons and the AppStream metadata are not installed by the cargo
    # build; upstream's Debian packaging picks them up from the same paths.
    postInstall = ''
      for size in 32 128 256 512; do
        install -Dm644 "assets/icon/''${size}x''${size}/ql_logo.png" \
          "$out/share/icons/hicolor/''${size}x''${size}/apps/io.github.Mrmayman.QuantumLauncher.png"
      done
      install -Dm644 assets/freedesktop/quantum-launcher.metainfo.xml \
        "$out/share/metainfo/io.github.Mrmayman.QuantumLauncher.metainfo.xml"
    '';

    # Upstream publishes tagged releases; version and hashes bump together.
    passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

    postFixup = ''
      wrapProgram $out/bin/quantum_launcher \
        --suffix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs}
      # The driver libraries live outside every closure; the hook only
      # provides the function, so it needs an explicit call on the wrapped
      # binary.
      addDriverRunpath $out/bin/.quantum_launcher-wrapped
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
