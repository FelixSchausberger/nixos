{
  lib,
  fetchFromGitHub,
  buildGoModule,
}:
buildGoModule rec {
  pname = "adguard-exporter";
  version = "unstable-2026-08-04";

  # AdGuard Home 0.107 (nixpkgs's latest) has no native /metrics endpoint;
  # this exporter scrapes the AdGuard REST API instead.
  src = fetchFromGitHub {
    owner = "Belphemur";
    repo = "adguard-exporter";
    rev = "eecea64023a47c453446490c57fecac66ba12096";
    sha256 = "0d9gnfh5c926wja3cl67i9a85jcj6cb6gliqjvfgw8fd8l33rb0n";
  };

  vendorHash = "sha256-yhUsU4sUir62QLtfiP4GAcOo+pK4Nrw91QfCFOy4I10=";

  meta = with lib; {
    description = "Prometheus exporter for AdGuard Home";
    homepage = "https://github.com/Belphemur/adguard-exporter";
    license = licenses.mit;
    maintainers = [];
    mainProgram = "adguard-exporter";
    platforms = platforms.linux;
  };
}
