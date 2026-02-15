{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "garnix-insights";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "shift";
    repo = "garnix-insights";
    rev = "v${version}";
    hash = "sha256-1+AYlr00TWXU/72rNigx9HQQSSr9Tx0r1TkLdzBvWU4=";
  };

  cargoHash = "sha256-EmCsmKZsHDY65HlSNYYEG5LxXrpvh2GB0tzKE07bsZg=";

  meta = with lib; {
    description = "CLI, server, and MCP interface for Garnix CI/CD insights";
    longDescription = ''
      Garnix Insights provides comprehensive CI/CD insights from Garnix.io
      through multiple interfaces: CLI tool, HTTP server, and MCP server
      for AI assistant integration.
    '';
    homepage = "https://github.com/shift/garnix-insights";
    license = licenses.agpl3Only;
    mainProgram = "garnix-insights";
    maintainers = [];
    platforms = platforms.linux;
  };
}
