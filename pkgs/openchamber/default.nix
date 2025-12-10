{
  lib,
  nodejs_20,
  makeWrapper,
  cacert,
  stdenv,
}:
stdenv.mkDerivation rec {
  pname = "openchamber";
  version = "1.5.3";

  src = builtins.fetchurl {
    url = "https://registry.npmjs.org/@openchamber/web/-/web-1.5.3.tgz";
    sha256 = "1hzg60xf7c4ds81q9qdyh6l7q5imcywyndzm99v0ypigkh8g2bsw";
  };

  nativeBuildInputs = [makeWrapper nodejs_20];

  # Skip build phase - npm package is pre-built
  buildPhase = ''
    runHook preBuild

    # Just extract the pre-built npm package
    export HOME=$(mktemp -d)

    runHook postBuild
  '';

  # Install the CLI and supporting files
  installPhase = ''
    runHook preInstall

    # Create output directory
    mkdir -p $out/{bin,lib/openchamber}

    # Copy available files (whatever exists in the npm package)
    cp -r bin $out/lib/openchamber/ 2>/dev/null || true
    cp -r server $out/lib/openchamber/ 2>/dev/null || true
    cp -r public $out/lib/openchamber/ 2>/dev/null || true
    cp -r package.json $out/lib/openchamber/ 2>/dev/null || true
    cp -r dist $out/lib/openchamber/ 2>/dev/null || true

    # Make CLI executable and create wrapper
    chmod +x $out/lib/openchamber/bin/cli.js
    makeWrapper $out/lib/openchamber/bin/cli.js $out/bin/openchamber \
      --prefix PATH : ${nodejs_20}/bin \
      --set NODE_EXTRA_CA_CERTS "${cacert}/etc/ssl/certs/ca-bundle.crt"

    runHook postInstall
  '';

  # Disable tests as the npm package is already tested
  doCheck = false;

  meta = with lib; {
    description = "Desktop and web interface for OpenCode AI agent";
    longDescription = ''
      OpenChamber provides a web and desktop interface for OpenCode AI coding
      agent. It offers cross-device continuity, remote access, and a familiar GUI
      workflow for developers who prefer visual interfaces over TUI.

      Features:
      - Integrated terminal with smart tool visualization
      - Git operations with AI commit message generation
      - Multi-agent runs from a single prompt
      - Mobile-first web interface with PWA support
      - Remote access via Cloudflare tunnels
    '';
    homepage = "https://github.com/btriapitsyn/openchamber";
    license = licenses.mit;
    mainProgram = "openchamber";
    maintainers = [];
    platforms = platforms.linux ++ platforms.darwin;
    broken = false;
  };
}
