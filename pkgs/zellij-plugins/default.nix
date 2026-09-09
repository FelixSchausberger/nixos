{
  lib,
  callPackage,
  zellij,
}: let
  # Tile version must match the running zellij server (nixpkgs zellij); each
  # plugin's Cargo.lock pins the same version.
  tileVersion = zellij.version;
  builder = callPackage ./build-wasm.nix {};
in {
  # Auto-global plugins (loaded via load_plugins / HM programs.zellij.plugins)
  zjstatus-hints = builder.buildZellijPlugin {
    pname = "zjstatus-hints";
    version = "0.1.4";
    owner = "b0o";
    repo = "zjstatus-hints";
    rev = "f4493113019ec78c28c420e5d092aae894967397";
    hash = "sha256-4KceZNBUuc2+V6sER0c7eouP0KcMEqdKgSjaddSXhGY=";
    cargoLock = ./zjstatus-hints.Cargo.lock;
    cargoPatches = [./zjstatus-hints.patch];
    inherit tileVersion;
    description = "Wrap zjstatus and render keybind hints for the current mode";
    homepage = "https://github.com/b0o/zjstatus-hints";
    license = lib.licenses.mit;
  };
  # On-demand plugins (launched via LaunchOrFocusPlugin keybind)
  harpoon = builder.buildZellijPlugin {
    pname = "harpoon";
    version = "0.3.0";
    owner = "Nacho114";
    repo = "harpoon";
    rev = "7553290e22516c230e598e4fa81d91b1714a0a08";
    hash = "sha256-JmYcbzxIF6qZs2/RKuspHqNpyDibGp9CVQJj47y/BOQ=";
    cargoLock = ./harpoon.Cargo.lock;
    cargoPatches = [./harpoon.patch];
    inherit tileVersion;
    description = "Jumplist for quickly navigating between often-used panes";
    homepage = "https://github.com/Nacho114/harpoon";
    license = lib.licenses.mit;
  };
  zellij-forgot = builder.buildZellijPlugin {
    pname = "zellij-forgot";
    version = "0.4.2";
    owner = "karimould";
    repo = "zellij-forgot";
    rev = "64001df4d23267796c254bc4c0810890fc5af75b";
    hash = "sha256-QS09lC6yyUZA13PHERrdY/phfo1QoHAmRPpQUGL3pP8=";
    cargoLock = ./zellij-forgot.Cargo.lock;
    # Second patch: tile 0.45 added the `no_focus` field to Action::Run.
    cargoPatches = [
      ./zellij-forgot.patch
      ./zellij-forgot-0.45.patch
    ];
    inherit tileVersion;
    binaryName = "zellij_forgot";
    description = "Searchable keybind reference for the current mode";
    homepage = "https://github.com/karimould/zellij-forgot";
    license = lib.licenses.mit;
  };
}
