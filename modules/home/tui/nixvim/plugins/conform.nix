{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.editors) languages;

  withFormatter = lib.filter (lang: lang.formatter != null) languages;

  # Conform formatter key: the bare command, disambiguated per language when
  # the shared args differ (e.g. dprint-toml vs dprint-markdown).
  formatterName = lang:
    if lang.formatter.args == []
    then lang.formatter.command
    else "${lang.formatter.command}-${lang.name}";

  # One definition per formatter name; duplicates (same command, no args)
  # carry identical bodies, so overwriting is harmless.
  formatterDefs =
    lib.foldl' (
      acc: lang:
        acc
        // {
          ${formatterName lang} =
            {command = lang.formatter.command;}
            // lib.optionalAttrs (lang.formatter.args != []) {args = lang.formatter.args;};
        }
    ) {}
    withFormatter;

  # Filetypes saved with auto-format, mirroring Helix's per-language
  # auto-format flag (null and false both mean "off", like Helix's default).
  autoFormatFiletypes = lib.concatMap (lang: lang.filetypes) (lib.filter (lang: lang.autoFormat == true) languages);

  filetypeList = lib.concatMapStringsSep ", " (ft: ''"${ft}"'') autoFormatFiletypes;
in {
  programs.nixvim = {
    # rustfmt is the one formatter of the shared set that home.packages does
    # not ship (the Rust toolchain normally comes from devShells); on nvim's
    # PATH it keeps format-on-save and the conform :checkhealth working in
    # plain shells too.
    extraPackages = [pkgs.rustfmt];

    plugins.conform-nvim = {
      enable = true;

      settings = {
        formatters_by_ft =
          lib.foldl' (
            acc: lang: acc // lib.genAttrs lang.filetypes (_: [(formatterName lang)])
          ) {}
          withFormatter;

        formatters = formatterDefs;

        # Only the auto-format filetypes save-format; other buffers keep the
        # save untouched. lsp_format = fallback formats via LSP when a language
        # has no formatter configured, exactly like Helix. The generous timeout
        # keeps slow formatters (rustfmt, black) from aborting mid-save.
        format_on_save = ''
          function(bufnr)
            local enabled = { ${filetypeList} }
            if vim.tbl_contains(enabled, vim.bo[bufnr].filetype) then
              return { lsp_format = "fallback", timeout_ms = 10000 }
            end
          end
        '';
      };
    };
  };
}
