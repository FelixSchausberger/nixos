{
  lib,
  callPackage,
  zellij,
}: let
  # Tile version must match the running zellij server (nixpkgs zellij); each
  # plugin's Cargo.lock pins the same version. Bumping zellij therefore means
  # regenerating every lock below and porting the patches, then bumping
  # pluginTileVersion with them. The assertion keeps a bare nixpkgs bump from
  # failing later in cargo with an opaque offline-resolution error.
  pluginTileVersion = "0.46.0";
  tileVersion = zellij.version;
  builder = callPackage ./build-wasm.nix {};
in
  assert lib.assertMsg (zellij.version == pluginTileVersion) ''
    zellij ${zellij.version} needs the plugin set relocked (targets ${pluginTileVersion}):
    regenerate pkgs/zellij-plugins/*.Cargo.lock, port the source patches, then update
    pluginTileVersion in pkgs/zellij-plugins/default.nix to zellij ${zellij.version}.''; {
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
    # v0.3.1 upstream targets zellij-tile 0.45.1; the local lock and patch port
    # it to 0.46.0 (Text::new became Text::from). Drop both once upstream ships
    # a 0.46 port.
    harpoon = builder.buildZellijPlugin {
      pname = "harpoon";
      version = "0.3.1";
      owner = "Nacho114";
      repo = "harpoon";
      rev = "fd5834a1bb4e076f0a54f6c966a6617247aaf317";
      hash = "sha256-IEZqo6wHkL/7KUaX6rFuXyy6PwW/Dgywam/bgTQEZ0Q=";
      cargoLock = ./harpoon.Cargo.lock;
      cargoPatches = [./harpoon-0.46.patch];
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
      cargoPatches = [./zellij-forgot.patch];
      inherit tileVersion;
      binaryName = "zellij_forgot";
      description = "Searchable keybind reference for the current mode";
      homepage = "https://github.com/karimould/zellij-forgot";
      license = lib.licenses.mit;
    };
  }
