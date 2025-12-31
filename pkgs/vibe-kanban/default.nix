{
  lib,
  stdenv,
  fetchFromGitHub,
  rustPlatform,
  nodejs_22,
  pnpm,
  pnpmConfigHook,
  fetchPnpmDeps,
  cargo,
  rustc,
  pkg-config,
  perl,
  openssl,
  sqlite,
  llvmPackages,
  makeWrapper,
}:
stdenv.mkDerivation rec {
  pname = "vibe-kanban";
  version = "0.0.143";

  src = fetchFromGitHub {
    owner = "BloopAI";
    repo = "vibe-kanban";
    # Version tags include timestamps
    rev = "v${version}-20251229180119";
    hash = "sha256-tRodhn+0jVrVaidQOlTjYAAL2cHDcihzFnMZ59UiCVc=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit src;
    hash = "sha256-a3U5Lt73YM92PH9XYLLd4OtBO0wvT3b4R2XAJliPeEk=";
  };

  nativeBuildInputs = [
    nodejs_22
    pnpm
    pnpmConfigHook
    cargo
    rustc
    pkg-config
    perl
    llvmPackages.libclang
    makeWrapper
    rustPlatform.cargoSetupHook
  ];

  buildInputs = [
    openssl
    sqlite
    llvmPackages.libclang.lib
  ];

  # Set LIBCLANG_PATH for bindgen
  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

  pnpmDeps = fetchPnpmDeps {
    inherit pname version src;
    # Fetcher version for pnpm dependency fetching (1, 2, or 3)
    fetcherVersion = 3;
    hash = "sha256-zWOX6cv9jpEr2X8sIHEDcKYjdJI5dR5Q1QtfZWnm5kg=";
  };

  # Build frontend first (required for rust-embed)
  buildPhase = ''
    runHook preBuild

    echo "Building frontend with pnpm..."
    cd frontend
    pnpm build
    cd ..

    echo "Building Rust binaries..."
    cargo build --release --bins

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # Install main server binary
    install -Dm755 target/release/server $out/bin/vibe-kanban

    # Install review binary if it exists
    if [ -f target/release/review ]; then
      install -Dm755 target/release/review $out/bin/vibe-kanban-review
    fi

    # Wrap binaries with runtime library paths
    for bin in $out/bin/*; do
      wrapProgram $bin \
        --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath buildInputs}
    done

    runHook postInstall
  '';

  meta = with lib; {
    description = "Task orchestration platform for AI coding agents";
    longDescription = ''
      Vibe Kanban is a task orchestration platform designed to maximize
      productivity with AI coding agents like Claude Code. Features include
      switching between different agents, running multiple agents in parallel
      or sequence, and centralizing MCP configurations.
    '';
    homepage = "https://github.com/BloopAI/vibe-kanban";
    license = licenses.agpl3Only;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "vibe-kanban";
  };
}
