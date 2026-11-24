# Seed for the Zen kiosk profile, run as the browser unit's ExecStartPre.
#
# Kept as its own derivation so the idempotence check in flake-parts/dev.nix
# builds the same script the service runs.
{
  lib,
  writeShellApplication,
  coreutils,
  # Home Manager's declarative files for the kiosk profile.
  userJs,
  userChrome,
  extensions,
}: let
  q = lib.escapeShellArg;
in
  writeShellApplication {
    name = "media-kiosk-profile-seed";
    runtimeInputs = [coreutils];
    text = ''
      profile="$HOME/.config/zen/kiosk"

      # mkdir -p accepts the 0555 extensions directory a Home Manager
      # activation leaves behind and still creates the tree on a profile the
      # persistence mount emptied.
      mkdir -p "$profile/chrome" "$profile/extensions"

      # Fill only what is missing, linking to the same store paths Home
      # Manager links. A copy over a link turns the link into a regular file
      # that the next activation moves aside as .backup, and the read-only
      # extensions directory rejects rewrites outright. Firefox keeps cookies,
      # logins and storage in the mounted directory untouched either way.
      if [ ! -e "$profile/user.js" ]; then
        ln -sfn ${q (toString userJs)} "$profile/user.js"
      fi
      if [ ! -e "$profile/chrome/userChrome.css" ]; then
        ln -sfn ${q (toString userChrome)} "$profile/chrome/userChrome.css"
      fi
      for ext in ${q (toString extensions)}/*; do
        [ -e "$ext" ] || continue
        dest="$profile/extensions/$(basename "$ext")"
        if [ ! -e "$dest" ]; then
          ln -sfn "$ext" "$dest"
        fi
      done
      if [ ! -e "$profile/.keep" ]; then
        touch "$profile/.keep"
      fi
    '';
  }
