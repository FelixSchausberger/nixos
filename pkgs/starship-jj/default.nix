{
  rustPlatform,
  fetchFromGitLab,
  lib,
}:
rustPlatform.buildRustPackage rec {
  pname = "starship-jj";
  version = "0.7.0";

  src = fetchFromGitLab {
    owner = "lanastara_foss";
    repo = "starship-jj";
    rev = version;
    hash = "sha256-EgOKjPJK6NdHghMclbn4daywJ8oODiXkS48Nrn5cRZo=";
  };

  cargoHash = "sha256-NNeovW27YSK/fO2DjAsJqBvebd43usCw7ni47cgTth8=";

  meta = with lib; {
    description = "Starship plugin for jj (Jujutsu VCS)";
    longDescription = ''
      Starship plugin for jj that uses the jj-cli crate for better
      performance than multiple jj invocations. Shows bookmarks,
      commit state, and file change metrics.
    '';
    homepage = "https://gitlab.com/lanastara_foss/starship-jj";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "starship-jj";
  };
}
