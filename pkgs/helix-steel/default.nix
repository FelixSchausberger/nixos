{
  lib,
  fetchFromGitHub,
  rustPlatform,
  git,
  makeWrapper,
}:
rustPlatform.buildRustPackage rec {
  pname = "helix-steel";
  version = "unstable-2026-02-13";

  src = fetchFromGitHub {
    owner = "mattwparas";
    repo = "helix";
    rev = "a8e53bc18385a545885a2a63e1bcfd2f4fb42318";
    hash = "sha256-XhBkqkoPFnxgtEcWfhoH9/k5xFwWHd/UWUjGS2BEpVo=";
  };

  cargoLock = {
    lockFile = "${src}/Cargo.lock";
    outputHashes = {
      "steel-core-0.8.1" = "sha256-YUYypFlZJcwMJFBFdy5mAFEmBNh4FW/opDMHo7R0Lkk=";
      "steel-derive-0.8.1" = "sha256-YUYypFlZJcwMJFBFdy5mAFEmBNh4FW/opDMHo7R0Lkk=";
      "steel-doc-0.8.1" = "sha256-YUYypFlZJcwMJFBFdy5mAFEmBNh4FW/opDMHo7R0Lkk=";
      "steel-gen-0.8.1" = "sha256-YUYypFlZJcwMJFBFdy5mAFEmBNh4FW/opDMHo7R0Lkk=";
      "steel-parser-0.8.1" = "sha256-YUYypFlZJcwMJFBFdy5mAFEmBNh4FW/opDMHo7R0Lkk=";
      "steel-quickscope-0.3.1" = "sha256-YUYypFlZJcwMJFBFdy5mAFEmBNh4FW/opDMHo7R0Lkk=";
      "steel-rc-0.8.1" = "sha256-YUYypFlZJcwMJFBFdy5mAFEmBNh4FW/opDMHo7R0Lkk=";
    };
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
