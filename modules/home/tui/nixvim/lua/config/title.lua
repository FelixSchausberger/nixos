-- Window title for Niri's mode-based border rules. Niri matches on the
-- "nvim [MODE]" titlestring, so the mode names must stay in sync with the
-- border rules in modules/home/wm/niri.
local mode_names = {
  n = "NORMAL",
  i = "INSERT",
  v = "VISUAL",
  V = "V-LINE",
  ["\22"] = "V-BLOCK",
  c = "COMMAND",
  R = "REPLACE",
  r = "PROMPT",
  ["!"] = "SHELL",
  t = "TERMINAL",
}

local function update_niri_title()
  local mode = vim.fn.mode()
  local mode_str = mode_names[mode] or "NORMAL"
  vim.opt.titlestring = "nvim [" .. mode_str .. "]"
end

vim.api.nvim_create_autocmd({ "ModeChanged", "VimEnter" }, {
  callback = update_niri_title,
})
