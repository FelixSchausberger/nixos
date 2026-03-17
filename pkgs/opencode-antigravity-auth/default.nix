{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nodejs_20,
}:
buildNpmPackage rec {
  pname = "opencode-antigravity-auth";
  version = "1.3.2";

  src = fetchFromGitHub {
    owner = "NoeFabris";
    repo = "opencode-antigravity-auth";
    rev = "v${version}";
    hash = "sha256-iyT4WDc3WUSqhLPj//keD1hNO3Rv7wLx0rsvBL7pJy0=";
  };

  nodejs = nodejs_20;

  npmDepsHash = "sha256-4Qh8CjdQtlZPqpcfOzqoT18iddVUfoL8+SrNUCiw8fE=";

  meta = with lib; {
    description = "Google Antigravity IDE OAuth auth plugin for Opencode - access Gemini 3 Pro and Claude 4.5 using Google credentials";
    homepage = "https://github.com/NoeFabris/opencode-antigravity-auth";
    license = licenses.mit;
    maintainers = ["Felix Schausberger"];
    platforms = platforms.linux ++ platforms.darwin;
  };
}
