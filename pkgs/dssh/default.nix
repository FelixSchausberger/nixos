{
  lib,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
}:
buildGoModule rec {
  pname = "dssh";
  version = "2.2.1";

  src = fetchFromGitHub {
    owner = "madLinux7";
    repo = "dssh";
    rev = "v${version}";
    hash = "sha256-Q4haiz8YKDDC+PXvDrmnfa2PjrPYvyKHqJ7YQaw8FQk=";
  };

  vendorHash = "sha256-PZo3pKNXDIHvR2KNTaAL+pFi1LNMxGF8/f/dTdye5gk=";

  # Upstream stamps its release version into main.version; the stripping
  # (-s -w) the Makefile also passes happens in the default fixup phase.
  ldflags = ["-X main.version=${version}"];

  # Upstream's test suite is pure Go (no TTY or keyring); buildGoModule runs
  # it with `go test ./...` in the sandbox.
  doCheck = true;

  # Upstream publishes tagged releases; the update is a version-and-hash bump.
  passthru.updateScript = nix-update-script {extraArgs = ["--flake"];};

  meta = with lib; {
    description = "Dead-simple SSH connection manager CLI and TUI";
    homepage = "https://dssh.grolmes.com";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "dssh";
  };
}
