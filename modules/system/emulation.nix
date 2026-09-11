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

  # Per-title box art for the Moonlight app grid, fetched from
  # libretro-thumbnails. Moonshine rescales each image to its 600x801 boxart
  # canvas before serving it, so the source aspect does not matter.
  boxartBase = {
    gc = "https://raw.githubusercontent.com/libretro-thumbnails/Nintendo_-_GameCube/master/Named_Boxarts";
    n64 = "https://raw.githubusercontent.com/libretro-thumbnails/Nintendo_-_Nintendo_64/master/Named_Boxarts";
    snes = "https://raw.githubusercontent.com/libretro-thumbnails/Nintendo_-_Super_Nintendo_Entertainment_System/master/Named_Boxarts";
  };

  boxart = name: url: hash:
    pkgs.fetchurl {
      inherit name url hash;
    };

  # Shared tile metadata. Moonshine's default 2s launch timeout is too short
  # for cold-starting emulators/Wine prefixes; journal logging keeps failed
  # launches diagnosable (the default discards application output). gamemode
  # wraps every tile for the GPU/CPU optimizations from gaming.nix. Tiles
  # without boxart fall back to automatic icon resolution by title.
  appTile = {
    title,
    args,
    boxart ? null,
  }:
    {
      inherit title;
      command = ["${pkgs.gamemode}/bin/gamemoderun"] ++ args;
      launch_timeout_secs = 20;
      stdout = "journal";
      stderr = "journal";
    }
    // lib.optionalAttrs (boxart != null) {inherit boxart;};

  # GLideN64 (RMG's N64 video plugin) defaults to a 640x480 fullscreen mode and
  # renders the GL viewport at exactly that size without scaling to the window,
  # so on a Moonshine virtual display (sized to the Moonlight client's
  # requested resolution) the game appears in a small block in one corner.
  # Point the plugin's fullscreen mode at the client resolution before each
  # launch; Moonshine exports MOONSHINE_CLIENT_WIDTH/HEIGHT/FRAMERATE for every
  # application it starts, and GLideN64 reads these values from
  # GLideN64.ini ([General] profile=User -> [User] video\fullscreen*).
  #
  # aspect=1 pins the 4:3 output (0=stretch, 1=4:3, 2=16:9, 3=adjust) so a
  # widescreen client output shows the game pillarboxed rather than stretched.
  rmgMoonshine = pkgs.writeShellApplication {
    name = "rmg-moonshine";
    runtimeInputs = with pkgs; [crudini coreutils];
    text = ''
      ini="''${HOME}/.config/RMG/GLideN64.ini"

      # A failed edit must not block the stream; log and launch with the
      # existing configuration instead.
      set_ini() {
        crudini --set "$ini" User "$1" "$2" \
          || echo "rmg-moonshine: could not set $1 in $ini" >&2
      }

      # Local launches without a client resolution keep the existing config.
      if [ -n "''${MOONSHINE_CLIENT_WIDTH:-}" ] && [ -n "''${MOONSHINE_CLIENT_HEIGHT:-}" ]; then
        if [ ! -f "$ini" ]; then
          mkdir -p "$(dirname "$ini")"
          printf '[General]\nprofile=User\n\n[User]\n' > "$ini"
        fi
        set_ini 'video\fullscreenWidth' "$MOONSHINE_CLIENT_WIDTH"
        set_ini 'video\fullscreenHeight' "$MOONSHINE_CLIENT_HEIGHT"
        set_ini 'frameBufferEmulation\aspect' 1
        if [ -n "''${MOONSHINE_CLIENT_FRAMERATE:-}" ]; then
          set_ini 'video\fullscreenRefresh' "$MOONSHINE_CLIENT_FRAMERATE"
        fi
      fi

      exec ${pkgs.rmg}/bin/RMG --fullscreen "$@"
    '';
  };

  # ROM paths relative to /per/mnt/games/Emulator
  gcGames = {
    "F-Zero GX" = {
      rom = "Gamecube/Games/F-Zero GX (USA).iso";
      boxart = boxart "moonshine-boxart-f-zero-gx.png" "${boxartBase.gc}/F-Zero%20GX%20(USA).png" "sha256-0eW54B7BlX7XHH0HPAtWlMqOPjD/gK3YVEniDlccYlo=";
    };
    "Zelda Collector's Edition" = {
      rom = "Gamecube/Games/Legend of Zelda, The - Collector's Edition (USA).iso";
      boxart = boxart "moonshine-boxart-zelda-ce.png" "${boxartBase.gc}/Legend%20of%20Zelda%2C%20The%20-%20Collector%27s%20Edition%20(USA).png" "sha256-TrWwmd/wFiDrbOAJ8GsRwkTKkN7bYbgmoC/NyjlgP/c=";
    };
    "Zelda Wind Waker" = {
      rom = "Gamecube/Games/Legend of Zelda, The - The Wind Waker (USA).iso";
      boxart = boxart "moonshine-boxart-zelda-ww.png" "${boxartBase.gc}/Legend%20of%20Zelda%2C%20The%20-%20The%20Wind%20Waker%20(USA).png" "sha256-nnU9LAoVfjWNflXtZSEusthpxtvOFwDBOPltWGS3bRo=";
    };
    "Super Monkey Ball" = {
      rom = "Gamecube/Games/Super Monkey Ball (USA).iso";
      boxart = boxart "moonshine-boxart-monkey-ball.png" "${boxartBase.gc}/Super%20Monkey%20Ball%20(USA).png" "sha256-Y+/8bY5Ww9HolqyiCprpUyCjLTW+iZcN6JfYHpV7m2Y=";
    };
  };

  n64Games = {
    "Pokemon Stadium" = {
      rom = "Pokemon Stadium.z64";
      boxart = boxart "moonshine-boxart-pokemon-stadium.png" "${boxartBase.n64}/Pokemon%20Stadium%20(USA).png" "sha256-7+ySi7sPG+DPzIPop1yYImRJqQPjdE3z1e5ekSFPJk4=";
    };
    "F-Zero X" = {
      rom = "Raspberry Pi/F-Zero X (USA)/F-Zero X (USA).z64";
      boxart = boxart "moonshine-boxart-f-zero-x.png" "${boxartBase.n64}/F-Zero%20X%20(USA).png" "sha256-8sjeKlzrK1YrdeiCeLwhi2v1lMTbZXnzYJN6g2FfmJM=";
    };
  };

  snesGames = {
    "Zelda A Link to the Past" = {
      rom = "Raspberry Pi/Legend of Zelda, The - A Link to the Past (Europe)/Legend of Zelda, The - A Link to the Past (Europe).sfc";
      boxart = boxart "moonshine-boxart-link-to-the-past.png" "${boxartBase.snes}/Legend%20of%20Zelda%2C%20The%20-%20A%20Link%20to%20the%20Past%20(Europe).png" "sha256-ZMef/rQ4o3MwJLfPOeTk0nkO6RMPVobUtVn2ZD7tpcw=";
    };
    "F-Zero" = {
      rom = "Raspberry Pi/F-Zero (E)/F-Zero (Europe).sfc";
      boxart = boxart "moonshine-boxart-f-zero-snes.png" "${boxartBase.snes}/F-Zero%20(Europe).png" "sha256-Hb7qY9mxzo6vj+yGn5BB2C/5+SBtxmiXxAfzNEPnf3Y=";
    };
  };

  # Wine games launched through Lutris rungame URIs. The slugs must match the
  # seeded Lutris entries in home/profiles/desktop/lutris-games/. Cyberpunk
  # 2077 is deliberately absent: it streams via the Steam application scanner
  # after a one-time import as a Steam shortcut (steam-rom-manager). These
  # have no libretro-thumbnails box art (PC titles) and no local Lutris
  # coverart source, so they fall back to title-based icon resolution.
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
      # GameCube/Wii via Dolphin. `-b` hides the GUI, which forces a separate
      # render window at RenderWindowWidth/Height (640x480) unless fullscreen
      # is requested; the Moonshine compositor only force-fills Steam windows,
      # so pin fullscreen explicitly. FullscreenDisplayRes=Auto keeps the game
      # at the client resolution while Dolphin's default aspect stays 4:3.
      (lib.mapAttrsToList
        (title: g:
          appTile {
            inherit title;
            inherit (g) boxart;
            args = [
              "${pkgs.dolphin-emu}/bin/dolphin-emu"
              "-b"
              "-C"
              "Dolphin.Display.Fullscreen=True"
              "-C"
              "Dolphin.Display.FullscreenDisplayRes=Auto"
              "${romDir}/${g.rom}"
            ];
          })
        gcGames)
      ++ (lib.mapAttrsToList
        (title: g:
          appTile {
            inherit title;
            inherit (g) boxart;
            args = [
              "${rmgMoonshine}/bin/rmg-moonshine"
              "${romDir}/${g.rom}"
            ];
          })
        n64Games)
      # snes9x's X11 fullscreen path only scales with Xvideo; without it the
      # SNES image is drawn at a fixed 2x (512x478) centered in the output.
      # Xvideo without -maxaspect scales to full height while keeping the
      # native aspect, so the game fills the display without stretching.
      ++ (lib.mapAttrsToList
        (title: g:
          appTile {
            inherit title;
            inherit (g) boxart;
            args = [
              "${pkgs.snes9x}/bin/snes9x"
              "-fullscreen"
              "-xvideo"
              "${romDir}/${g.rom}"
            ];
          })
        snesGames)
      ++ (lib.mapAttrsToList
        (title: slug:
          appTile {
            inherit title;
            args = [
              "${pkgs.lutris}/bin/lutris"
              "lutris:rungame/${slug}"
            ];
          })
        lutrisGames)
      ++ [
        # Client launchers: games are picked inside the frontend (Epic login,
        # Minecraft instances)
        (appTile {
          title = "Epic Games (Heroic)";
          args = ["${pkgs.heroic}/bin/heroic"];
        })
        (appTile {
          title = "Minecraft (QuantumLauncher)";
          args = ["/etc/profiles/per-user/${config.hostConfig.user}/bin/quantum_launcher"];
        })
      ];
  };
}
