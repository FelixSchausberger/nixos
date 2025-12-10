{
  lib,
  fetchFromGitHub,
  rustPlatform,
  git,
  makeWrapper,
}:
rustPlatform.buildRustPackage rec {
  pname = "helix-steel";
  version = "unstable-2025-12-17";

  src = fetchFromGitHub {
    owner = "mattwparas";
    repo = "helix";
    rev = "refs/heads/steel-event-system";
    hash = "sha256-xDVuEKcBIY4cA7g9UwI8keimoHxQz/+fUXY7DA8EcsA=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    allowBuiltinFetchGit = true;
  };

  nativeBuildInputs = [
    git
    makeWrapper
  ];

  # Enable Steel plugin system
  buildFeatures = ["steel"];

  # Disable auto grammar build as we'll handle runtime separately
  HELIX_DISABLE_AUTO_GRAMMAR_BUILD = "1";

  # Build only the main helix binary
  cargoBuildFlags = ["--package" "helix-term"];

  # Skip tests for now to speed up build
  doCheck = false;

  postInstall = ''
    # Copy runtime files (grammars, queries, themes) from source
    mkdir -p $out/lib
    cp -r ${src}/runtime $out/lib/runtime

    # Wrap installed binary to set HELIX_RUNTIME
    wrapProgram $out/bin/hx \
      --set HELIX_RUNTIME "$out/lib/runtime"
  '';

  meta = with lib; {
    description = "Helix editor with Steel plugin system (steel-event-system branch)";
    longDescription = ''
      A custom build of Helix text editor from the steel-event-system branch,
      which includes support for Steel-based plugins. This enables extending
      Helix with Scheme-like scripting capabilities.
    '';
    homepage = "https://github.com/mattwparas/helix/tree/steel-event-system";
    license = licenses.mpl20;
    mainProgram = "hx";
    maintainers = [];
    platforms = platforms.linux;
  };
}
