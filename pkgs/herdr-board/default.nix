# herdr-board: the interactive agent-kanban seat for the ocws workflow. A
# card carries a prompt, harness/model/effort settings, and a target herdr
# session plus space; moving a card into a `trigger = auto` column dispatches
# a real agent pane; agents comment and report through the `board` CLI. The
# seat composes with ocws rather than replacing it: ocws keeps the jj-derived
# states and the claim descriptions, cards are optional per task (label =
# task, cwd = workspace directory), and ocws's removal paths cancel and
# archive the cards they claim (guard-silent when `board` is absent).
# Pinned to an upstream release tag, not a floating rev: herdr-board is young
# (first release 2026-08, single human maintainer) and its schema/board
# protocol version gates are documented in-band; the pin is bumped by hand
# after checking the CHANGELOG, never silently.
{
  lib,
  fetchFromGitHub,
  pkg-config,
  rustPlatform,
  sqlite,
}:
rustPlatform.buildRustPackage rec {
  pname = "herdr-board";
  version = "0.19.1";

  src = fetchFromGitHub {
    owner = "nelsonPires5";
    repo = "herdr-board";
    # tag v0.19.1
    rev = "7a215a179acb4e098dd1c2971332497806309360";
    hash = "sha256-uJUyHprpt8tregwcQR/PUj+mky0g1v1nmfq7r20tTDs=";
  };

  # Upstream pins its dependency closure in Cargo.lock; using it keeps the
  # build offline and reproducible.
  cargoLock.lockFile = "${src}/Cargo.lock";

  # The cargo setup hook points libsqlite3-sys at the system library
  # (LIBSQLITE3_SYS_USE_PKG_CONFIG), which takes precedence over the crate's
  # `bundled` feature, so the link step needs sqlite and its .pc file.
  nativeBuildInputs = [pkg-config];
  buildInputs = [sqlite];

  # The release binary is the product (one `board` binary: TUI, CLI, daemon).
  # Upstream's test battery is a staged e2e suite that needs a live Herdr
  # session, so a packaging build only proves the binary compiles.
  doCheck = false;

  meta = {
    description = "Kanban board for AI coding agents: cards dispatch agent runs into herdr panes";
    homepage = "https://github.com/nelsonPires5/herdr-board";
    license = lib.licenses.mit;
    mainProgram = "board";
    platforms = lib.platforms.linux;
  };
}
