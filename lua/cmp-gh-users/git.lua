---@class cmp.gh.users.Git
---Provides functions for working with git repositories.
local git = {}

local Job = require("plenary.job")
local cfg = require("cmp-gh-users.config"):get()
local log = require("cmp-gh-users.logger").new("cmp-gh-users.git", cfg.log_level)

--- Get the remote URL for the `origin` remote.
---@param remote string The remote name.
---@param callback fun(remote: string|nil)
---@return nil
function git.remote(remote, callback)
  log("getting remote URL for " .. remote, vim.log.levels.DEBUG)
  Job:new({
    "git",
    "remote",
    "get-url",
    "--push",
    remote,
    on_exit = function(job, exit_code)
      if exit_code == 0 then
        local remote_url = job:result()[1]
        log("got remote URL " .. remote_url, vim.log.levels.DEBUG)
        callback(job:result()[1])
      else
        log("failed to get remote URL for " .. remote, vim.log.levels.DEBUG)
        callback(nil)
      end
    end,
  }):start()
end

return git
