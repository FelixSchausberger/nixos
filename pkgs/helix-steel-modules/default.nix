{
  lib,
  stdenv,
}:
stdenv.mkDerivation {
  pname = "helix-steel-modules";
  version = "0.1.0";

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
        mkdir -p $out/lib/helix-cogs/helix

        # Create components.scm wrapper for the builtin helix/components module
        cat > $out/lib/helix-cogs/helix/components.scm << 'EOF'
    ;; Wrapper for builtin helix/components module
    ;; Re-exports all functions from the Rust-based components module
    (require-builtin helix/components)
    (provide (all-from helix/components))
    EOF

        # Create misc.scm wrapper for helix misc functionality
        cat > $out/lib/helix-cogs/helix/misc.scm << 'EOF'
    ;; Wrapper for helix misc functionality
    ;; This module provides miscellaneous helix utilities
    (require-builtin helix/core)
    (provide (all-from helix/core))
    EOF

        echo "Installed helix Steel module wrappers:"
        ls -la $out/lib/helix-cogs/helix/
  '';

  meta = with lib; {
    description = "Steel module wrappers for Helix editor";
    longDescription = ''
      Provides .scm wrapper files that re-export builtin Helix Steel modules,
      allowing Steel plugins to require them using the .scm extension syntax.
    '';
    license = licenses.mpl20;
    platforms = platforms.linux;
  };
}
