# Desktop shell selector for Wayland compositors.
# Selects which shell stack owns bar, launcher, notifications, lock screen,
# wallpaper, idle management, and OSD on a per-host basis. The "custom" value
# preserves the hand-assembled stack (ironbar, walker, wired, cthulock, awww,
# stasis, avizo); "wayle", "noctalia", and "dms" progressively replace
# those parts.
# Shell modules are parameterized by session target elsewhere; this file only
# declares the user-facing knob so profiles set it without touching modules.
{lib, ...}: {
  options.wm.shell = lib.mkOption {
    type = lib.types.enum [
      "custom"
      "wayle"
      "noctalia"
      "dms"
    ];
    default = "custom";
    description = ''
      Desktop shell stack for Wayland sessions on this host.

      - custom: hand-assembled stack (ironbar, walker, wired, cthulock,
        awww, stasis). Default; preserves current behavior.
      - wayle: Rust/GTK4 shell (bar, notifications, OSD, device controls).
        Keeps walker (launcher), cthulock (lock), awww (wallpaper), and
        stasis (idle) from the custom stack.
      - noctalia: native C++ shell owning the full layer. Disables
        ironbar, walker, wired, cthulock, awww, stasis, avizo, and
        wl-gammarelay to keep single ownership of each protocol.
      - dms: Dank Material Shell (quickshell + Go daemon), full layer
        including a dynamic island. Owns the same protocol set as
        noctalia (launcher, notifications, OSD, idle, lock, wallpaper,
        night mode) and disables the same custom-stack parts.
    '';
    example = "wayle";
  };
}
