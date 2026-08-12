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
  # We therefore build every plugin from source with `wasm32-wasip1` and patch
  # the upstream source to compile against `zellij-tile 0.44.3`, matching the
  # pinned zellij server.
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
    # Source patches: bump zellij-tile to 0.44.3 and port any API changes.
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
