-- Connection details for the shared OpenCode server.
--
-- OpenCode 2 generates an HTTP basic-auth password per install and publishes
-- the running service (URL and password) as JSON in its state directory. The
-- nixvim integration must use that exact URL and password to join the same
-- session store as `oc` and the web UI; neither can be pinned in the Nix
-- store. The file name mirrors upstream's channel naming: this build's `prod`
-- channel writes `service-prod.json`, other channels write `service.json`.
local M = {}

local FILES = { "service-prod.json", "service.json" }

---Read the running service registration, or nil when the server is not up.
---@return { url: string?, password: string? }?
local function registration()
  local state_home = vim.env.XDG_STATE_HOME
  local home = vim.env.HOME or ""
  local state_dir = (state_home and state_home ~= "")
      and vim.fs.joinpath(state_home, "opencode")
    or vim.fs.joinpath(home, ".local", "state", "opencode")

  for _, name in ipairs(FILES) do
    local ok, lines = pcall(vim.fn.readfile, vim.fs.joinpath(state_dir, name))
    if ok and lines and #lines > 0 then
      local decoded_ok, decoded = pcall(vim.fn.json_decode, table.concat(lines, "\n"))
      if decoded_ok and type(decoded) == "table" then
        return decoded
      end
    end
  end
  return nil
end

---@return string?
function M.url()
  local reg = registration()
  return type(reg) == "table" and type(reg.url) == "string" and reg.url or nil
end

---@return string?
function M.password()
  local reg = registration()
  return type(reg) == "table" and type(reg.password) == "string" and reg.password or nil
end

return M
