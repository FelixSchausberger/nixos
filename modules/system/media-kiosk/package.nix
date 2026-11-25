# Kiosk page assets, the small Python API, and the controller bridge.
#
# Kept as a plain derivation instead of a flake package: the app is wired to
# one host's session and is never consumed outside modules/system/media-kiosk.
{
  lib,
  stdenv,
  python3,
  makeWrapper,
  pkg-config,
  sdl3,
  curl,
  wtype,
  avizo,
  inter,
  wallpaper,
}:
stdenv.mkDerivation {
  pname = "media-kiosk";
  version = "1.0.0";
  src = ./.;

  nativeBuildInputs = [makeWrapper pkg-config];
  buildInputs = [sdl3 curl];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    ${python3}/bin/python3 -m py_compile server.py
    runHook postCheck
  '';

  buildPhase = ''
    runHook preBuild
    # Key injection and the avizo volume OSD are baked as store paths so the
    # systemd unit needs no PATH entry or wrapper script.
    $CC -O2 -Wall -Wextra -std=c11 \
      -DWTYPE_BIN='"${lib.getExe wtype}"' \
      -DVOLUMECTL_BIN='"${lib.getExe' avizo "volumectl"}"' \
      controller.c -o media-kiosk-controller \
      $(pkg-config --cflags --libs sdl3 libcurl)
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/media-kiosk/web/static $out/bin
    cp -r web/. $out/share/media-kiosk/web/
    install -m644 server.py $out/share/media-kiosk/server.py
    install -m755 media-kiosk-controller $out/bin/

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
    description = "Controller-first media kiosk page, action API, and controller bridge";
    mainProgram = "media-kiosk-api";
    platforms = lib.platforms.linux;
  };
}
