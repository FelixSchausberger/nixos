{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "jj-lsp";
  version = "0.1.1-dev1";

  src = fetchFromGitHub {
    owner = "nilskch";
    repo = "jj-lsp";
    rev = "775b0ac7e4c3e9e5b77dc04688d462269d274dc6";
    hash = "sha256-QjJXMZKu5RXkqV4MtY5JtyWjHvapFmZjmo+vIDONQmI=";
  };

  cargoLock.lockFile = "${src}/Cargo.lock";

  meta = with lib; {
    description = "LSP to resolve conflicts in the jj-vcs";
    longDescription = ''
      A Language Server Protocol (LSP) implementation for resolving conflicts
      in the jj version control system. Provides conflict highlighting, code
      actions for resolution, and document links for navigating conflict sides.
    '';
    homepage = "https://github.com/nilskch/jj-lsp";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.all;
  };
}
