# Emulator and non-Steam game library. Moonshine launches application tiles
# with the system PATH, so every binary referenced by a tile must live in
# environment.systemPackages — home.packages would be invisible to the
# streaming service even though it works in local desktop sessions.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.modules.system.emulation;

  romDir = "/per/mnt/games/Emulator";

  # Shared tile metadata. Moonshine's default 2s launch timeout is too short
  # for cold-starting emulators/Wine prefixes; journal logging keeps failed
  # launches diagnosable (the default discards application output). gamemode
  # wraps every tile for the GPU/CPU optimizations from gaming.nix.
  appTile = title: args: {
    inherit title;
    command = ["${pkgs.gamemode}/bin/gamemoderun"] ++ args;
    launch_timeout_secs = 20;
    stdout = "journal";
    stderr = "journal";
  };

  # ROM paths relative to /per/mnt/games/Emulator
  gcGames = {
    "F-Zero GX" = "Gamecube/Games/F-Zero GX (USA).iso";
    "Zelda Collector's Edition" = "Gamecube/Games/Legend of Zelda, The - Collector's Edition (USA).iso";
    "Zelda Wind Waker" = "Gamecube/Games/Legend of Zelda, The - The Wind Waker (USA).iso";
    "Super Monkey Ball" = "Gamecube/Games/Super Monkey Ball (USA).iso";
  };

  n64Games = {
    "Pokemon Stadium" = "Pokemon Stadium.z64";
    "F-Zero X" = "Raspberry Pi/F-Zero X (USA)/F-Zero X (USA).z64";
  };

  snesGames = {
    "Zelda A Link to the Past" = "Raspberry Pi/Legend of Zelda, The - A Link to the Past (Europe)/Legend of Zelda, The - A Link to the Past (Europe).sfc";
    "F-Zero" = "Raspberry Pi/F-Zero (E)/F-Zero (Europe).sfc";
  };

  # Wine games launched through Lutris rungame URIs. The slugs must match the
  # seeded Lutris entries in home/profiles/desktop/lutris-games/. Cyberpunk
  # 2077 is deliberately absent: it streams via the Steam application scanner
  # after a one-time import as a Steam shortcut (steam-rom-manager).
  lutrisGames = {
    "Dark Souls Remastered" = "dark-souls-remastered";
    "GTA San Andreas" = "gta-san-andreas";
    "NFS Most Wanted" = "need-for-speed-most-wanted";
    "NFS Underground 2" = "need-for-speed-underground-2";
    "Diablo II" = "diablo-2";
    "N-Ball" = "n-ball";
    "Ragdoll Masters" = "ragdoll-masters";
    "Super Stealball" = "super-stealball";
  };
in {
  options.modules.system.emulation = {
    enable = lib.mkEnableOption "emulators and non-Steam game library with Moonlight tiles";
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.modules.system.gaming.enable;
        message = "modules.system.emulation.enable requires modules.system.gaming.enable (gamemode for tile wrappers)";
      }
    ];

    environment.systemPackages = with pkgs; [
      # Emulators (tiles launch them directly, one tile per game)
      dolphin-emu
      rmg
      snes9x

      # Game frontends/clients
      lutris
      heroic # Epic/GOG/Amazon launcher (Epic login is interactive, once)
      steam-rom-manager # one-time Steam shortcut import for Cyberpunk 2077
    ];

    modules.system.moonshine.extraApplications =
      # GameCube/Wii via Dolphin (-b boots the ROM directly)
      (lib.mapAttrsToList
        (title: rom:
          appTile title [
            "${pkgs.dolphin-emu}/bin/dolphin-emu"
            "-b"
            "${romDir}/${rom}"
          ])
        gcGames)
      ++ (lib.mapAttrsToList
        (title: rom:
          appTile title [
            "${pkgs.rmg}/bin/RMG"
            "--fullscreen"
            "${romDir}/${rom}"
          ])
        n64Games)
      ++ (lib.mapAttrsToList
        (title: rom:
          appTile title [
            "${pkgs.snes9x}/bin/snes9x"
            "-fullscreen"
            "${romDir}/${rom}"
          ])
        snesGames)
      ++ (lib.mapAttrsToList
        (title: slug:
          appTile title [
            "${pkgs.lutris}/bin/lutris"
            "lutris:rungame/${slug}"
          ])
        lutrisGames)
      ++ [
        # Client launchers: games are picked inside the frontend (Epic login,
        # Minecraft instances)
        (appTile "Epic Games (Heroic)" [
          "${pkgs.heroic}/bin/heroic"
        ])
        (appTile "Minecraft (QuantumLauncher)" [
          "/etc/profiles/per-user/${config.hostConfig.user}/bin/quantum_launcher"
        ])
      ];
  };
}
