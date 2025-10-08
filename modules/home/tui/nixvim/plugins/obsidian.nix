{
  programs.nixvim.plugins = {
    # https://github.com/hrsh7th/nvim-cmp
    cmp.enable = true; # A completion plugin

    obsidian = {
      enable = true;

      # Workspace configuration
      settings = {
        # Workspaces - you can configure multiple vaults
        workspaces = [
          {
            name = "personal";
            path = "/per/mnt/gdrive/Obsidian";
          }
          # Add more workspaces as needed:
          # {
          #   name = "work";
          #   path = "~/Documents/work-vault";
          # }
        ];

        # Completion settings
        completion = {
          # Set to false to disable completion
          nvim_cmp = true;
          # Trigger completion at 2 chars
          min_chars = 2;
          # Where to put new notes. Valid options are
          #  * "current_dir" - put new notes in same directory as the current buffer
          #  * "notes_subdir" - put new notes in the default notes subdirectory
          new_notes_location = "notes_subdir";
          # Whether to add the aliases, directory, and tags to the completion
          prepend_note_path = true;
          # Whether to add the note ID to the completion
          prepend_note_alias = true;
          # Whether to add the note path to the completion
          prepend_note_id = true;
          # Whether to add the note tags to the completion
          prepend_note_tags = true;
          # How many suggestions to show
          max_suggestions = 10;
          # How to sort suggestions
          sort_by = "modified";
          # Whether to sort by last modified time
          sort_reversed = true;
        };

        # Daily notes configuration
        daily_notes = {
          # Optional, if you keep daily notes in a separate directory
          folder = "daily";
          # Optional, if you want to change the date format for the ID of daily notes
          date_format = "%Y-%m-%d";
          # Optional, if you want to change the date format of the default alias of daily notes
          alias_format = "%B %-d, %Y";
          # Optional, if you want to automatically insert a template from your template directory like 'daily.md'
          template = null;
        };

        # Weekly notes configuration
        weekly_notes = {
          # Optional, if you keep weekly notes in a separate directory
          folder = "weekly";
          # Optional, if you want to change the date format for the ID of weekly notes
          date_format = "%Y-W%V";
          # Optional, if you want to change the date format of the default alias of weekly notes
          alias_format = "Week %V of %Y";
          # Optional, if you want to automatically insert a template from your template directory like 'weekly.md'
          template = null;
        };

        # Templates configuration
        templates = {
          # Where to look for templates
          folder = "templates";
          # Template date format
          date_format = "%Y-%m-%d";
          # Template time format
          time_format = "%H:%M";
          # Template substitutions
          substitutions = {
            # yesterday = function()
            #   return os.date("%Y-%m-%d", os.time() - 86400)
            # end
          };
        };

        # Note naming and location
        notes_subdir = "notes";
        # Function to generate note IDs
        note_id_func = "auto";
        # Whether to disable frontmatter
        disable_frontmatter = false;
        # Whether to prefer new notes over existing ones
        prefer_new_notes = false;

        # UI settings
        ui = {
          # Whether to enable the checkboxes
          enable_checkboxes = true;
          # Whether to show the current file path in the status line
          show_urls = "nofollow";
          # Whether to show the current file path in the status line
          show_path = true;
        };

        # Pickers configuration
        picker = {
          # Set to "telescope.nvim" to use telescope for pickers
          name = "telescope.nvim";
          # Optional, if you want to change the prompt for the picker
          prompt_title = "Obsidian";
        };

        # Syntax highlighting
        syntax = {
          # Whether to enable additional syntax highlighting
          enable = true;
          # Additional syntax groups to highlight
          additional_vim_regex_highlighting = false;
        };

        # Attachments
        attachments = {
          # The default folder to place images in via `:ObsidianPasteImg`
          img_folder = "attachments";
          # A function that determines the text to insert in the note when pasting an image
          img_text_func = "filename";
        };

        # Callbacks
        callbacks = {
          # Runs anytime you enter a buffer and it's a markdown file
          post_setup = null;
          # Runs anytime you enter a buffer and it's a markdown file
          enter_note = null;
          # Runs anytime you leave a buffer and it's a markdown file
          leave_note = null;
          # Runs anytime you enter a buffer and it's a markdown file
          pre_write_note = null;
          # Runs anytime you write a note
          post_write_note = null;
        };

        # Logging
        log_level = 1; # INFO level
      };
    };
  };
}
