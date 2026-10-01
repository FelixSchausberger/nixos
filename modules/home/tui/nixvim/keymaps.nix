_: {
  programs.nixvim = {
    keymaps = [
      # Write/quit (Helix space-w / space-q parity)
      {
        mode = "n";
        key = "<leader>w";
        action = "<cmd>w<cr>";
        options = {
          silent = true;
          desc = "Save file";
        };
      }
      {
        mode = "n";
        key = "<leader>q";
        action = "<cmd>q<cr>";
        options = {
          silent = true;
          desc = "Quit";
        };
      }

      # Find (fzf-lua)
      {
        mode = "n";
        key = "<leader>ff";
        action = "<cmd>lua require('fzf-lua').files()<cr>";
        options.desc = "Find files";
      }
      {
        mode = "n";
        key = "<leader>fg";
        action = "<cmd>lua require('fzf-lua').live_grep()<cr>";
        options.desc = "Live grep";
      }
      {
        mode = "n";
        key = "<leader>fb";
        action = "<cmd>lua require('fzf-lua').buffers()<cr>";
        options.desc = "Buffers";
      }
      {
        mode = "n";
        key = "<leader>fr";
        action = "<cmd>lua require('fzf-lua').oldfiles()<cr>";
        options.desc = "Recent files";
      }
      {
        mode = "n";
        key = "<leader>fh";
        action = "<cmd>lua require('fzf-lua').help_tags()<cr>";
        options.desc = "Help tags";
      }
      {
        mode = "n";
        key = "<C-p>";
        action = "<cmd>lua require('fzf-lua').files()<cr>";
        options.desc = "Find files";
      }

      # Buffers
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>bdelete<cr>";
        options = {
          silent = true;
          desc = "Delete buffer";
        };
      }
      {
        mode = "n";
        key = "<leader>bn";
        action = "<cmd>bnext<cr>";
        options = {
          silent = true;
          desc = "Next buffer";
        };
      }
      {
        mode = "n";
        key = "<leader>bp";
        action = "<cmd>bprevious<cr>";
        options = {
          silent = true;
          desc = "Previous buffer";
        };
      }

      # File explorer
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Oil<cr>";
        options = {
          silent = true;
          desc = "File explorer";
        };
      }

      # Yazi at the current file (replaces the previous terminal-tab variant)
      {
        mode = "n";
        key = "<leader>yy";
        action = "<cmd>Yazi<cr>";
        options = {
          silent = true;
          desc = "Yazi file manager";
        };
      }

      # Format the buffer (Helix space-F parity via conform)
      {
        mode = "n";
        key = "<leader>cf";
        action = "<cmd>lua require('conform').format({ lsp_format = 'fallback' })<cr>";
        options = {
          silent = true;
          desc = "Format buffer";
        };
      }

      # Cargo tasks via overseer's builtin cargo template (Helix space-c/b/r/t
      # parity). The template names contain spaces, so they go through
      # run_task() instead of :OverseerRun, whose argument parsing would keep
      # only the last word as the name.
      {
        mode = "n";
        key = "<leader>rc";
        action = "<cmd>lua require('overseer').run_task({ name = 'cargo check' })<cr>";
        options = {
          silent = true;
          desc = "cargo check";
        };
      }
      {
        mode = "n";
        key = "<leader>rb";
        action = "<cmd>lua require('overseer').run_task({ name = 'cargo build' })<cr>";
        options = {
          silent = true;
          desc = "cargo build";
        };
      }
      {
        mode = "n";
        key = "<leader>rr";
        action = "<cmd>lua require('overseer').run_task({ name = 'cargo run' })<cr>";
        options = {
          silent = true;
          desc = "cargo run";
        };
      }
      {
        mode = "n";
        key = "<leader>rt";
        action = "<cmd>lua require('overseer').run_task({ name = 'cargo test' })<cr>";
        options = {
          silent = true;
          desc = "cargo test";
        };
      }
      {
        mode = "n";
        key = "<leader>ro";
        action = "<cmd>OverseerToggle<cr>";
        options = {
          silent = true;
          desc = "Toggle task output";
        };
      }
    ];

    # Group labels: the keymap hints shown while a leader prefix is pending.
    plugins.which-key = {
      enable = true;
      settings.spec = [
        {
          __unkeyed-1 = "<leader>f";
          group = "Find";
        }
        {
          __unkeyed-1 = "<leader>c";
          group = "Code";
        }
        {
          __unkeyed-1 = "<leader>b";
          group = "Buffers";
        }
        {
          __unkeyed-1 = "<leader>r";
          group = "Run";
        }
        {
          __unkeyed-1 = "<leader>y";
          group = "Yazi";
        }
      ];
    };
  };
}
