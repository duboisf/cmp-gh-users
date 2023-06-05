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
      a.run(
        function()
          cache:load()
        end,
        function()
          local source = Source.new(remote.owner, cache)
          local expires_in = cache:expires_in(remote.owner)
          vim.loop.new_timer():start(
            expires_in * 1000,
            cfg.cache.max_age * 1000,
            vim.schedule_wrap(function()
              -- Prepare completion response in advance.
              -- It gets persisted to the cache so that it will be available
              -- immediately on the next completion request.
              ---@type fun(source: cmp.gh.users.Source)
              local prepare_completion_response = a.wrap(source.prepare_completion_response, 2)
              a.void(function()
                prepare_completion_response(source)
                cache:save()
              end)()
            end))
          vim.schedule(function()
            ---@diagnostic disable-next-line: param-type-mismatch
            require("cmp").register_source("gh_users", source)
          end)
        end)
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
