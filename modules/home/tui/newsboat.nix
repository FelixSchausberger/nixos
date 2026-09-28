# Terminal feed reader, used as the Hacker News reading queue. circumflex
# (see tui/default.nix) covers reading comment threads on demand, so newsboat
# only needs the feeds themselves; every link newsboat opens is dispatched by
# browser below, which reads in circumflex when no display is reachable.
#
# Home Manager symlinks config and urls from the Nix store into
# ~/.config/newsboat, so both are read-only: feeds are declared here and the
# in-app "a" command cannot add more. The cache stays mutable under
# ~/.local/share/newsboat and holds the read/unread state.
{
  pkgs,
  lib,
  ...
}: {
  programs.newsboat = {
    enable = true;

    # Cap per feed: the hnrss feeds below publish at most 30 items per fetch.
    maxItems = 30;

    # Reload on start and every 30 minutes while a session stays open; the
    # fetch timer below keeps the cache current while newsboat is closed.
    autoReload = true;
    reloadTime = 30;

    urls = [
      {
        url = "https://hnrss.org/frontpage";
        title = "HN Front Page";
        tags = ["hn"];
      }
      {
        url = "https://hnrss.org/best";
        title = "HN Best";
        tags = ["hn"];
      }
    ];

    # Link dispatcher, run interactively by newsboat (it suspends its TUI and
    # waits, so `q` in circumflex returns here). With a display reachable:
    # the session's $BROWSER, falling back to xdg-open. Without one (SSH or
    # tty into the homelab): HN discussion URLs to circumflex's comment view,
    # everything else to Reader Mode. Absolute store paths keep the script
    # independent of the caller's newsboat environment; newsboat appends the
    # URL single-quoted because the value carries no %u placeholder. The
    # derivation is interpolated to its store path because the option type is
    # a string. mkDefault so the WSL profile can override it with explorer.exe
    # without a conflict between two plain definitions of the option.
    browser = lib.mkDefault "${pkgs.writeShellScript "newsboat-browser" ''
      url="$1"
      if [ -n "''${DISPLAY:-}" ] || [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        exec "''${BROWSER:-${pkgs.xdg-utils}/bin/xdg-open}" "$url"
      fi
      case "$url" in
        *news.ycombinator.com/item?id=*)
          id="''${url##*id=}"
          exec ${pkgs.circumflex}/bin/clx comments "''${id%%&*}"
          ;;
        *)
          exec ${pkgs.circumflex}/bin/clx url "$url"
          ;;
      esac
    ''}";

    # Systemd user timers: warm the cache on a schedule and keep it from
    # growing without bound. The module wraps both in flock, so they cannot
    # collide with an interactive instance holding the cache lock.
    autoFetchArticles = {
      enable = true;
      onCalendar = "daily";
    };
    autoVacuum = {
      enable = true;
      onCalendar = "weekly";
    };

    # Queue flow: both mark-and-advance operations (Shift+N toggles read,
    # Shift+O opens and marks read) jump to the next unread afterwards, so
    # triage is one keystroke per item: open -> read in circumflex -> q ->
    # already on the next unread. Both default to no upstream.
    extraConfig = ''
      toggleitemread-jumps-to-next-unread yes
      openbrowser-and-mark-jumps-to-next-unread yes
    '';
  };
}
