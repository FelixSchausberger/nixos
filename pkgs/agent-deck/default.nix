{
  lib,
  buildGoModule,
  fetchFromGitHub,
  tmux,
  makeWrapper,
}:
buildGoModule rec {
  pname = "agent-deck";
  version = "0.8.4";

  src = fetchFromGitHub {
    owner = "asheshgoplani";
    repo = "agent-deck";
    rev = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  vendorHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  nativeBuildInputs = [makeWrapper];

  # Ensure tmux is available at runtime
  postInstall = ''
    wrapProgram $out/bin/agent-deck \
      --prefix PATH : ${lib.makeBinPath [tmux]}
  '';

  meta = with lib; {
    description = "Terminal session manager for AI coding agents built with Go and Bubble Tea";
    longDescription = ''
      Agent Deck is a terminal-based session manager specifically designed for
      AI coding assistants like Claude Code. Features include session forking
      to duplicate conversations with full context inheritance, global search
      across all sessions, MCP manager for attaching/detaching Model Context
      Protocol servers, and full integration with Claude Code.
    '';
    homepage = "https://github.com/asheshgoplani/agent-deck";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "agent-deck";
  };
}
