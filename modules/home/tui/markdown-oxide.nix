{pkgs, ...}: {
  # Install markdown-oxide package
  home.packages = with pkgs; [
    markdown-oxide
  ];

  # Shell alias for daily notes
  home.shellAliases = {
    daily = "fish -c 'set -l today (date +%Y-%m-%d); set -l file /per/mnt/gdrive/Obsidian/work/magazino/daily/$today.md; mkdir -p (dirname $file); touch $file; hx $file'";
  };

  # Create configuration directory and file
  xdg.configFile."moxide/settings.toml" = {
    text = ''
      # Markdown-Oxide Configuration
      # See https://oxide.md/Configuration for full reference

      # Leave blank to try to import from Obsidian Daily Notes
      dailynote = "%Y-%m-%d" # this is akin to YYYY-MM-DD from Obsidian

      # Fuzzy match file headings in completions
      heading_completions = true

      # Set true if you title your notes by the first heading
      title_headings = true

      # Show diagnostics for unresolved links
      unresolved_diagnostics = true

      semantic_tokens = true

      # Resolve tags in code blocks
      tags_in_codeblocks = false
      # Resolve references in code blocks
      references_in_codeblocks = false

      # The folder for new files to be created in
      new_file_folder_path = ""

      # The folder for new daily notes
      daily_notes_folder = "/per/mnt/gdrive/Obsidian/work/magazino/daily"

      # Whether markdown links should include an extension or not
      include_md_extension_md_link = false

      # Whether wikilinks should include an extension or not
      include_md_extension_wikilink = false

      # Enable hover
      hover = true

      # Handle case in fuzzy matches: Ignore | Smart | Respect
      case_matching = "Smart"

      # Enable inlay hints
      inlay_hints = true
      # Enable transclusion, in the form of inlay hints, for embedded block links
      block_transclusion = true
      # Full or Partial
      block_transclusion_length = "Full"
    '';
  };
}
