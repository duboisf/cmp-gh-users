local Cache = require("cmp-gh-users.cache")
local Source = require("cmp-gh-users.source")
local a = require("plenary.async")
local cfg = require("cmp-gh-users.config")
local fs = require("cmp-gh-users.fs")
local GitHub = require("cmp-gh-users.github")

local gh = GitHub.new()

gh:with_remote(function(remote)
  if remote then
    local cache = Cache.new(cfg.get().cache_file, 60 * 60, fs)
    a.void(function()
      cache:load()
      local source = Source.new(cache, remote.owner)
      vim.schedule(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        require("cmp").register_source("gh-users", source)
      end)
    end)()
  end
end)
