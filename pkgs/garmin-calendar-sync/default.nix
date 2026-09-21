{
  lib,
  python3Packages,
}:
python3Packages.buildPythonApplication {
  pname = "garmin-calendar-sync";
  version = "unstable-2026-09-21";
  format = "other";

  src = ./.;

  propagatedBuildInputs = with python3Packages; [
    icalendar
    python-dateutil
  ];

  # The InfluxDB/Grafana endpoints are loopback-only; urllib keeps the
  # closure small compared to requests/httpx.
  dontBuild = true;
  doCheck = false;

  installPhase = ''
    runHook preInstall
    install -Dm755 garmin-calendar-sync.py $out/bin/garmin-calendar-sync
    substituteInPlace $out/bin/garmin-calendar-sync \
      --replace-fail "#!/usr/bin/env python3" "#!${python3Packages.python}/bin/python"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Sync Nextcloud calendar events into Grafana annotations";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "garmin-calendar-sync";
  };
}
