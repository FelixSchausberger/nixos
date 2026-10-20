{pkgs, ...}: let
  # Persistent e-book library on the data mount. Calibre remembers the
  # last-opened library in its own config; this entry pins the first
  # launch so it never falls back to a library inside $HOME.
  booksLibrary = "/per/mnt/data/documents/books";
in {
  home.packages = with pkgs; [
    (calibre.override {
      unrarSupport = true; # Needed to open .cbr and .cbz files
    })
  ];

  # Override the packaged calibre-gui entry (user applications take
  # precedence over profile paths) so launcher and "open with" handlers
  # open the persistent library. Fields mirror upstream calibre-gui.desktop.
  xdg.desktopEntries."calibre-gui" = {
    type = "Application";
    name = "calibre";
    genericName = "E-book library management";
    comment = "E-book library management: Convert, view, share, catalogue all your e-books";
    exec = "calibre --with-library=${booksLibrary} %U";
    icon = "calibre-gui";
    categories = ["Office"];
    mimeType = [
      "application/epub+zip"
      "application/ereader"
      "application/oebps-package+xml"
      "application/pdf"
      "application/vnd.ms-word.document.macroenabled.12"
      "application/vnd.oasis.opendocument.text"
      "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      "application/x-cb7"
      "application/x-cbc"
      "application/x-cbr"
      "application/x-cbz"
      "application/x-mobi8-ebook"
      "application/x-mobipocket-ebook"
      "application/x-mobipocket-subscription"
      "application/x-sony-bbeb"
      "application/xhtml+xml"
      "image/vnd.djvu"
      "text/fb2+xml"
      "text/html"
      "text/plain"
      "text/rtf"
      "text/x-markdown"
      "x-scheme-handler/calibre"
    ];
    terminal = false;
    startupNotify = true;
    settings = {
      "X-GNOME-UsesNotifications" = "true";
      "Keywords" = "epub;ebook;manager";
      "TryExec" = "calibre";
    };
  };
}
