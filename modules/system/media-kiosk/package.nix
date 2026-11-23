# Kiosk page assets plus the small Python API that serves them.
#
# Kept as a plain derivation instead of a flake package: the app is wired to
# one host's session and is never consumed outside modules/system/media-kiosk.
{
  lib,
  stdenvNoCC,
  python3,
  makeWrapper,
  inter,
  wallpaper,
}:
stdenvNoCC.mkDerivation {
  pname = "media-kiosk";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [makeWrapper];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${python3}/bin/python3 -m py_compile server.py
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/media-kiosk/web/static $out/bin
    cp -r web/. $out/share/media-kiosk/web/
    install -m644 server.py $out/share/media-kiosk/server.py

    # Both fonts and wallpaper are served from this origin: the kiosk must not
    # depend on a CDN, and the projector can be up before the WAN is.
    install -m644 ${inter}/share/fonts/truetype/InterVariable.ttf \
      $out/share/media-kiosk/web/static/InterVariable.ttf
    install -m644 ${wallpaper} \
      $out/share/media-kiosk/web/static/wallpaper.jpg

    makeWrapper ${python3}/bin/python3 $out/bin/media-kiosk-api \
      --add-flags "$out/share/media-kiosk/server.py" \
      --set KIOSK_WEB_ROOT "$out/share/media-kiosk/web"

    runHook postInstall
  '';

  meta = {
    description = "Controller-first media kiosk page and action API";
    mainProgram = "media-kiosk-api";
    platforms = lib.platforms.linux;
  };
}
