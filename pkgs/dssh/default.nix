{
  lib,
  buildGoModule,
  fetchFromGitHub,
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

  ldflags = [
    "-s"
    "-w"
  ];

  doCheck = false;

  meta = with lib; {
    description = "Dead-simple SSH connection manager CLI and TUI";
    homepage = "https://dssh.grolmes.com";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "dssh";
  };
}
