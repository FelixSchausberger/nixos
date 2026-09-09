{
  lib,
  pkgs,
  stdenvNoCC,
  fetchFromGitHub,
}: let
  # Zellij plugins must be compiled against the exact zellij-utils/zellij-tile
  # version of the running zellij server. The plugin ABI changed frequently
  # (tuple-style Action variants became struct variants in 0.44), so prebuilt
  # wasm releases from GitHub are often incompatible and panic at runtime.
  #
  # We therefore build every plugin from source with `wasm32-wasip1` and force
  # the tile dependency to `tileVersion` (derived from the nixpkgs zellij
  # version by the caller), regardless of what upstream's Cargo.toml pins.
  # Source-level API ports beyond the version bump live in the per-plugin
  # cargoPatches. Changing tileVersion also requires regenerating each
  # plugin's Cargo.lock (cargo generate-lockfile) — the lock must contain the
  # forced tile version or the build fails on lock mismatch.
  wasm = pkgs.pkgsCross.wasm32-wasip1;
in {
  buildZellijPlugin = {
    pname,
    version,
    owner,
    repo,
    rev,
    hash,
    cargoLock,
    # zellij-tile/zellij-tile-utils version forced into Cargo.toml. Must match
    # the running zellij server (nixpkgs zellij) and the pinned Cargo.lock.
    tileVersion,
    # Source patches: port Action variant shapes and other tile API changes.
    cargoPatches ? [],
    binaryName ? pname,
    description,
    homepage,
    license,
  }: let
    unwrapped = wasm.rustPlatform.buildRustPackage {
      inherit pname version;
      src = fetchFromGitHub {
        inherit owner repo rev hash;
      };
      cargoLock.lockFile = cargoLock;
      inherit cargoPatches;
      postPatch = ''
        ${lib.getExe pkgs.gnused} -i -E \
          's|(zellij-tile(-utils)? = )"[^"]*"|\1"${tileVersion}"|' \
          Cargo.toml
        cp ${cargoLock} Cargo.lock
      '';
      nativeBuildInputs = [wasm.lld];
      env.RUSTFLAGS = "-C linker=wasm-ld";
      cargoBuildFlags = ["--bin=${binaryName}"];
      doCheck = false;
      meta = with lib; {
        description = "Zellij plugin ${pname}: ${description}";
        inherit homepage;
        inherit license;
        maintainers = [];
      };
    };
  in
    # Flatten the package output to a single .wasm file, matching the shape
    # Home Manager's `programs.zellij.plugins` expects (`zellij/plugins/<name>.wasm`).
    stdenvNoCC.mkDerivation {
      inherit (unwrapped) pname version;
      name = "zellij-plugin-${unwrapped.pname}-${unwrapped.version}.wasm";
      src = unwrapped;
      dontUnpack = true;
      buildPhase = ''
        resultFile=$(find "$src" -name '*.wasm')
        if [ $(echo "$resultFile" | wc -l) -ne 1 ]; then
          echo "The unwrapped plugin ($src) contains more than one WASM file"
          echo "$resultFile"
          exit 1
        fi
        cp "$resultFile" "$out"
      '';
      meta = unwrapped.meta // {platforms = lib.platforms.linux;};
    };
}
