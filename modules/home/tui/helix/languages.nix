{
  config,
  lib,
  ...
}: let
  inherit (config.editors) debuggers languages languageServers;

  # The shared data stores one argv per server; Helix wants command and args
  # as separate keys, plus its config table only when present.
  mkServer = server:
    {
      command = builtins.head server.cmd;
    }
    // lib.optionalAttrs (builtins.length server.cmd > 1) {
      args = lib.tail server.cmd;
    }
    // lib.optionalAttrs (server.config != {}) {
      inherit (server) config;
    };

  mkLanguage = lang:
    {
      inherit (lang) name scope;
      file-types = lang.fileTypes;
    }
    // lib.optionalAttrs (lang.servers != []) {language-servers = lang.servers;}
    // lib.optionalAttrs (lang.autoFormat != null) {auto-format = lang.autoFormat;}
    // lib.optionalAttrs (lang.formatter != null) {
      formatter =
        {
          command = lang.formatter.command;
        }
        // lib.optionalAttrs (lang.formatter.args != []) {args = lang.formatter.args;};
    }
    // lib.optionalAttrs (lang.rulers != null) {inherit (lang) rulers;}
    // lib.optionalAttrs (lang.textWidth != null) {text-width = lang.textWidth;}
    // lib.optionalAttrs (lang.softWrap != null) {soft-wrap.enable = lang.softWrap;}
    // lib.optionalAttrs (lang.commentToken != null) {comment-token = lang.commentToken;}
    // lib.optionalAttrs (lang.debugger != null) {inherit (lang) debugger;};
in {
  # Single programs.nhx.languages definition — nhx uses the deprecated
  # `types.attrs` type for this option, which cannot be merged across
  # multiple modules (shallow `//` merge drops one definition entirely).
  # The shared editors.* data renders into this one definition.
  programs.nhx.languages =
    {
      language-server = lib.mapAttrs (_: mkServer) languageServers;
    }
    // lib.optionalAttrs (debuggers != {}) {debugger = debuggers;}
    // {language = map mkLanguage languages;};
}
