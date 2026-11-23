# jjfx reads the jj store through jj-lib, so its version must match the jj in
# the flake. Pinned to the head of FelixSchausberger/jjfx#209 (jj/jj-lib
# 0.47.1) until the PR merges and a release contains it. Trial cockpit only:
# rookery keeps the claim, the review gate and the cleanup; jjfx's delete, tidy,
# pool and dispatch paths are not used, and its lifecycle hooks are not
# installed because the OpenCode config root is rendered read-only.
{
  lib,
  fetchFromGitHub,
  pkg-config,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "jjfx";
  version = "0.56.0-unstable-2026-11-18";

  src = fetchFromGitHub {
    owner = "FelixSchausberger";
    repo = "jjfx";
    rev = "27d7f1d3ee2b74df000a26a38962fc52f69c9b34";
    hash = "sha256-oXpbgs0BqgduillbioXUHKWzXtC/n6asapfHf2VfzOg=";
  };

  # Upstream pins its dependency closure in Cargo.lock; using it keeps the
  # build offline and reproducible.
  cargoLock.lockFile = "${src}/Cargo.lock";

  nativeBuildInputs = [pkg-config];

  # Upstream's process-supervision tests hardcode /usr/bin and fail on NixOS;
  # the PR author ran cargo test --lib and the bump-sensitive integration
  # targets. A packaging build only proves the binary compiles.
  doCheck = false;

  meta = {
    description = "TUI for Jujutsu workspaces and the coding agents editing them";
    homepage = "https://github.com/Jarvvski/jjfx";
    license = lib.licenses.gpl3Plus;
    mainProgram = "jjfx";
    platforms = lib.platforms.linux;
  };
}
