-- Explicit g:clipboard so :checkhealth and yanks work no matter where nvim
-- was launched from: builtin detection is gated on WAYLAND_DISPLAY/DISPLAY
-- and only succeeds inside an active graphical session. wl-clipboard is used
-- when a Wayland session is reachable; otherwise yanks travel as OSC 52
-- through the terminal (SSH, detached, or opencode-spawned sessions).
local osc52 = require("vim.ui.clipboard.osc52")
local wayland = vim.env.WAYLAND_DISPLAY
local use_wl = wayland ~= nil and wayland ~= "" and vim.fn.executable("wl-copy") == 1

vim.g.clipboard = use_wl
    and {
      name = "wl-clipboard",
      copy = { ["+"] = { "wl-copy" }, ["*"] = { "wl-copy" } },
      paste = {
        ["+"] = { "wl-paste", "--no-newline" },
        ["*"] = { "wl-paste", "--no-newline" },
      },
      cache_enabled = 0,
    }
  or {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
  }
