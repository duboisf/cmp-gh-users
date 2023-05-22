local Cache = require("cmp-gh-users.cache")
local GitHub = require("cmp-gh-users.github")
local Source = require("cmp-gh-users.source")
local a = require("plenary.async")
local cfg = require("cmp-gh-users.config").get()

local loaded = false

local init = function()
  if loaded then return end
  loaded = true
  GitHub.new():with_remote(function(remote)
    if remote then
      local cache = Cache.new()
      a.void(function()
        cache:load()
        local source = Source.new(remote.owner, cache)
        if cache:expired(remote.owner) then
          -- Prepare completion response in advance.
          -- It gets persisted to the cache so that it will be available
          -- immediately on the next completion request.
          source:get_completion_response()
        end
        vim.schedule(function()
          ---@diagnostic disable-next-line: param-type-mismatch
          require("cmp").register_source("gh_users", source)
        end)
      end)()
    end
  end)
end

local augroup = vim.api.nvim_create_augroup("cmp-gh-users", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  callback = init,
  desc = "Initialize cmp-gh-users",
  group = augroup,
  pattern = cfg.filetypes,
  once = true, -- fires once per filetype
})
