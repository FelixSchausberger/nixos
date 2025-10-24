{
  stdenv,
  fetchurl,
  lib,
}:
stdenv.mkDerivation rec {
  pname = "zellij-ghost";
  version = "0.6.0";

  src = fetchurl {
    url = "https://github.com/vdbulcke/ghost/releases/download/v${version}/ghost.wasm";
    sha256 = "11rvy39lvv5q4v7n6xg5hsj0yyc5hlzw9aw7rmc17jm6i2fdzx7v";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/zellij/plugins
    cp $src $out/share/zellij/plugins/ghost.wasm
    runHook postInstall
  '';

  meta = with lib; {
    description = "Zellij plugin for executing Fish shell commands in a floating terminal";
    homepage = "https://github.com/vdbulcke/ghost";
    license = licenses.asl20;
    platforms = platforms.all;
    maintainers = [];
  };
}
