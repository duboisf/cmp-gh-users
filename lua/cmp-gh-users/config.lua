local M = {}

---@class cmp.gh.users.Config
local config = {
  ---Settings related to the cache.
  ---@class cmp.gh.users.Config.Cache
  cache = {
    ---The maximum age of a cache item in seconds. Defaults to 1 hour.
    max_age = 60 * 60, -- 1 hour
    ---The path to the cache file. Defaults to `vim.fn.stdpath("cache") .. "/cmp-gh-users.json"`.
    path = vim.fn.stdpath("cache") .. "/cmp-gh-users.json",
  },
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
