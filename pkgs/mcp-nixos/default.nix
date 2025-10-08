{
  lib,
  stdenv,
  fetchFromGitHub,
  go,
}:
stdenv.mkDerivation rec {
  pname = "mcp-nixos";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "utensils";
    repo = "mcp-nixos";
    rev = "50b02bcba32b941d2ec48fedef68641702ca5b0f";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Will fix this
  };

  nativeBuildInputs = [go];

  buildPhase = ''
    runHook preBuild
    go build -o mcp-nixos
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp mcp-nixos $out/bin/
    runHook postInstall
  '';

  meta = with lib; {
    description = "NixOS MCP server for Claude Code";
    homepage = "https://github.com/utensils/mcp-nixos";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux ++ platforms.darwin;
    mainProgram = "mcp-nixos";
  };
}
