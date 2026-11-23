{
  lib,
  python3Packages,
  makeWrapper,
  awww,
  imagemagick,
}:
python3Packages.buildPythonApplication {
  pname = "wallpaper-conditions";
  version = "0.1.0";
  pyproject = true;
  src = ./.;

  build-system = [python3Packages.setuptools];
  dependencies = [python3Packages.astral];
  nativeBuildInputs = [makeWrapper];

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    python -m unittest discover -s tests -v
    runHook postCheck
  '';

  # The CLI shells out to awww for the wallpaper and to ImageMagick for the
  # overview blur. Both are runtime inputs, not build dependencies.
  postFixup = ''
    wrapProgram "$out/bin/wallpaper-conditions" \
      --prefix PATH : ${lib.makeBinPath [awww imagemagick]}
  '';

  meta = with lib; {
    description = "Condition-aware wallpaper selection for awww";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "wallpaper-conditions";
  };
}
