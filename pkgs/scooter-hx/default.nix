{
  lib,
  fetchFromGitHub,
  rustPlatform,
}:
rustPlatform.buildRustPackage rec {
  pname = "scooter-hx";
  version = "unstable-2025-12-17";

  src = fetchFromGitHub {
    owner = "thomasschafer";
    repo = "scooter.hx";
    rev = "refs/heads/main";
    hash = "sha256-gwQVCOa7ll5yx4T9hgVtuehxf7IF+rbIO9EahU6BfzY=";
  };

  cargoHash = "sha256-dGpQXUr+Ny2Kq3S75Qksluy3H8ajec+jsOf/0elSkVs=";

  # Build only the library
  cargoBuildFlags = ["--lib"];

  # Skip tests for faster build
  doCheck = false;

  postInstall = ''
    # Create plugin directory structure at cogs level
    mkdir -p $out/lib/helix-plugins/scooter
    mkdir -p $out/lib/helix-plugins/ui

    # Copy the compiled library to both scooter and ui directories
    # (UI modules need access to the dylib via #%require-dylib)
    if [ -f $out/lib/libscooter_hx.so ]; then
      cp $out/lib/libscooter_hx.so $out/lib/helix-plugins/scooter/
      cp $out/lib/libscooter_hx.so $out/lib/helix-plugins/ui/
    elif [ -f $out/lib/libscooter_hx.dylib ]; then
      cp $out/lib/libscooter_hx.dylib $out/lib/helix-plugins/scooter/
      cp $out/lib/libscooter_hx.dylib $out/lib/helix-plugins/ui/
    else
      echo "Error: Could not find compiled scooter library in $out/lib"
      ls -la $out/lib
      exit 1
    fi

    # Copy Scheme files to scooter directory
    cp ${src}/scooter.scm $out/lib/helix-plugins/scooter/
    cp ${src}/cog.scm $out/lib/helix-plugins/scooter/

    # Copy ui directory to cogs level (sibling to scooter)
    cp -r ${src}/ui/* $out/lib/helix-plugins/ui/

    # List what we installed for debugging
    echo "Installed scooter plugin structure:"
    ls -la $out/lib/helix-plugins/
    ls -la $out/lib/helix-plugins/scooter/
    ls -la $out/lib/helix-plugins/ui/
  '';

  meta = with lib; {
    description = "Find-and-replace plugin for Helix with Steel support";
    longDescription = ''
      Scooter is a find-and-replace plugin for the Helix editor that uses
      the Steel plugin system. It provides enhanced search and replace
      functionality through Steel's Scheme-like scripting interface.
    '';
    homepage = "https://github.com/thomasschafer/scooter.hx";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
