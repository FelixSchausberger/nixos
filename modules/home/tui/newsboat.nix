# Terminal feed reader, used as the Hacker News reading queue. circumflex
# (see tui/default.nix) covers reading comment threads on demand, so newsboat
# only needs the feeds themselves.
#
# Home Manager symlinks config and urls from the Nix store into
# ~/.config/newsboat, so both are read-only: feeds are declared here and the
# in-app "a" command cannot add more. The cache stays mutable under
# ~/.local/share/newsboat and holds the read/unread state.
{
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
  };
}
