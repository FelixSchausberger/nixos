-- scooter (project-wide find and replace) integration. The TUI runs in a
-- snacks terminal float; pressing `e` on a result shells back into this
-- Neovim instance through $NVIM. See plugins/scooter.nix for the scooter-side
-- editor_open command and the keymaps that call the functions below.
local scooter_term = nil

-- Invoked by scooter via `nvim --server $NVIM --remote-send`. Must be global
-- (and named exactly this) because it is called from scooter's command line.
_G.EditLineFromScooter = function(file_path, line)
  if scooter_term and scooter_term:buf_valid() then
    scooter_term:hide()
  end

  local current_path = vim.fn.expand("%:p")
  local target_path = vim.fn.fnamemodify(file_path, ":p")
  if current_path ~= target_path then
    vim.cmd.edit(vim.fn.fnameescape(file_path))
  end
  vim.api.nvim_win_set_cursor(0, { line, 0 })
end

local function open_scooter(cmd)
  if scooter_term and scooter_term:buf_valid() then
    scooter_term:close()
  end
  scooter_term = require("snacks").terminal.open(cmd, {
    win = { position = "float", height = 0.85, width = 0.9 },
  })
end

function _G.scooter_open()
  open_scooter("scooter")
end

-- Visual mode: prefill scooter's search field with the selection as a fixed
-- string (newlines flattened) and keep the unnamed register intact.
function _G.scooter_open_selection()
  local saved = vim.fn.getreg('"')
  vim.cmd('normal! "ay')
  local text = vim.fn.getreg("a")
  vim.fn.setreg('"', saved)
  open_scooter("scooter --fixed-strings --search-text " .. vim.fn.shellescape((text:gsub("\r?\n", " "))))
end
