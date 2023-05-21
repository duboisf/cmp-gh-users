local Cache = require("cmp-gh-users.cache")
local GitHub = require("cmp-gh-users.github")
local Source = require("cmp-gh-users.source")
local a = require("plenary.async")

GitHub.new():with_remote(function(remote)
  if remote then
    local cache = Cache.new()
    a.void(function()
      cache:load()
      local source = Source.new(remote.owner, cache)
      vim.schedule(function()
        ---@diagnostic disable-next-line: param-type-mismatch
        require("cmp").register_source("gh-users", source)
      end)
    end)()
  end
end)
