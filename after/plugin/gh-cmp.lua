local Cache = require "cmp-gh-users.cache"
local Source = require "cmp-gh-users.source"
local async = require "plenary.async"
local fs = require "cmp-gh-users.fs"
local github = require "cmp-gh-users.github"

---@type string
local cache_file = vim.fn.stdpath("cache") .. "/cmp-gh-users.json"

github.when_in_github_repo(function(remote)
  local cache = Cache.new(cache_file, 60 * 60, fs)
  async.run(
    function() cache:load() end,
    function()
      local source = Source.new(cache, remote.owner)
      vim.schedule_wrap(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        require("cmp").register_source("gh-users", source)
      end)()
    end)
end)
