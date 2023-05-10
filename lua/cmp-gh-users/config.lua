local M = {}

---@class cmp.gh.users.Config
local config = {
  ---The path to the cache file. Defaults to `vim.fn.stdpath("cache") .. "/cmp-gh-users.json"`.
  cache_file = vim.fn.stdpath("cache") .. "/cmp-gh-users.json",
  ---The minimum vim log level to log, see `:help vim.log.levels`.
  log_level = vim.log.levels.WARN,
}

---@return cmp.gh.users.Config
function M.get()
  -- Return a copy of the config table.
  return vim.tbl_extend("force", {}, config)
end

---@param new_config cmp.gh.users.Config
---@return nil
function M.set(new_config)
  -- Set the config table.
  config = vim.tbl_extend("force", config, new_config)
end

return M
