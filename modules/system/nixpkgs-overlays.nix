# Shared nixpkgs overlays for package fixes that are not upstream yet
_: {
  nixpkgs.overlays = [
    # Calibre-Web's binary_helper.resolve_binary_path only accepts a kepubify
    # binary whose basename is kepubify-linux-64bit (or a directory containing
    # it), while the kepubify package installs bin/kepubify and the calibre-web
    # NixOS module seeds exactly that path - so every config save fails with
    # "Kepubify binary not found" and on-the-fly kepub conversion never runs.
    # Rename the real binary to the expected name and keep bin/kepubify as a
    # compat symlink for anything referencing it (the module's seeded path
    # resolves through realpath).
    (_final: prev: {
      kepubify = prev.kepubify.overrideAttrs (old: {
        postInstall =
          (old.postInstall or "")
          + ''
            mv $out/bin/kepubify $out/bin/kepubify-linux-64bit
            ln -s kepubify-linux-64bit $out/bin/kepubify
          '';
      });
    })
  ];
}
