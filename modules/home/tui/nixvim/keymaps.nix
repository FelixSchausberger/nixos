{config, ...}: let
  # nixvim's helper for embedding Lua functions in keymaps.
  inherit (config.lib.nixvim) mkRaw;
in {
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

      # Terminal: snacks float (plugins/snacks.nix), independent of the
      # docked overseer output panel.
      {
        mode = "n";
        key = "<leader>tt";
        action = mkRaw ''function() require("snacks").terminal.toggle(vim.o.shell, { win = { position = "float", height = 0.6, width = 0.9 } }) end'';
        options = {
          silent = true;
          desc = "Toggle floating terminal";
        };
      }

      # Rust: rustaceanvim targets. The cargo tasks stay on <leader>r*; these
      # run/target-test at the cursor and drive the nvim-dap session.
      {
        mode = "n";
        key = "<leader>rR";
        action = "<cmd>RustLsp runnables<cr>";
        options = {
          silent = true;
          desc = "Rust runnables";
        };
      }
      {
        mode = "n";
        key = "<leader>rd";
        action = "<cmd>RustLsp debuggables<cr>";
        options = {
          silent = true;
          desc = "Rust debuggables";
        };
      }
      {
        mode = "n";
        key = "<leader>rT";
        action = "<cmd>RustLsp testables<cr>";
        options = {
          silent = true;
          desc = "Rust testables";
        };
      }
      {
        mode = "n";
        key = "<leader>re";
        action = "<cmd>RustLsp explainError<cr>";
        options = {
          silent = true;
          desc = "Rust explain error";
        };
      }

      # Git hunks (gitsigns): navigation plus the common hunk actions.
      {
        mode = "n";
        key = "]c";
        action = mkRaw ''function() require("gitsigns").nav_hunk("next") end'';
        options = {
          silent = true;
          desc = "Next git hunk";
        };
      }
      {
        mode = "n";
        key = "[c";
        action = mkRaw ''function() require("gitsigns").nav_hunk("prev") end'';
        options = {
          silent = true;
          desc = "Previous git hunk";
        };
      }
      {
        mode = ["n" "x"];
        key = "<leader>gs";
        action = mkRaw ''function() require("gitsigns").stage_hunk() end'';
        options = {
          silent = true;
          desc = "Stage hunk";
        };
      }
      {
        mode = ["n" "x"];
        key = "<leader>gr";
        action = mkRaw ''function() require("gitsigns").reset_hunk() end'';
        options = {
          silent = true;
          desc = "Reset hunk";
        };
      }
      {
        mode = "n";
        key = "<leader>gp";
        action = mkRaw ''function() require("gitsigns").preview_hunk() end'';
        options = {
          silent = true;
          desc = "Preview hunk";
        };
      }
      {
        mode = "n";
        key = "<leader>gb";
        action = mkRaw ''function() require("gitsigns").blame_line({ full = true }) end'';
        options = {
          silent = true;
          desc = "Blame line";
        };
      }

      # Paste over a selection without clobbering the unnamed register; the
      # black-hole register keeps the yanked text available (:h quote_).
      {
        mode = "x";
        key = "p";
        action = "\"_dP";
        options.desc = "Paste without yanking selection";
      }

      # Esc clears the search highlight (Helix parity); normal mode only, so
      # terminal mode keeps its own Esc.
      {
        mode = "n";
        key = "<Esc>";
        action = "<cmd>nohlsearch<cr>";
        options = {
          silent = true;
          desc = "Clear search highlight";
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
          __unkeyed-1 = "<leader>s";
          group = "Search";
        }
        {
          __unkeyed-1 = "<leader>t";
          group = "Terminal";
        }
        {
          __unkeyed-1 = "<leader>g";
          group = "Git";
        }
        {
          __unkeyed-1 = "<leader>y";
          group = "Yazi";
        }
      ];
    };
  };
}
