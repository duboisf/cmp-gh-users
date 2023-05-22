local GitHub = require("cmp-gh-users.github")
local a = require "plenary.async"
local cfg = require("cmp-gh-users.config").get()
local log = require("cmp-gh-users.logger").new("cmp-gh-users.source", cfg.log_level)

---@alias BufferNumber number

---@class cmp.gh.users.Source
---@field private cache cmp.gh.users.Cache
---@field private github_owner string
---@field private gh cmp.gh.users.GitHub
---@field private fetching boolean Are we fetching users?
local source = {}

---@class cmp.gh.users.Source.Config
local default_config = {
  fs = require("cmp-gh-users.fs"),
  gh = GitHub.new(),
}

---@enum cmp.gh.users.SocialAccountProviderIcon
local social_account_provider_icons = {
  TWITTER = "",
}

---@param social_accounts cmp.gh.users.SocialAccount[]
---@return string
local function format_social_accounts(social_accounts)
  local results = {}
  for _, social_account in ipairs(social_accounts) do
    local icon = social_account_provider_icons[social_account.provider] or ""
    if icon ~= "" then
      icon = icon .. " "
    end
    table.insert(results, string.format("%s[%s](%s)", icon, social_account.displayName, social_account.url))
  end
  return table.concat(results, "\n")
end

---Format documentation for nvim-cmp
---@param data cmp.gh.users.CompletionItemData
---@return string
local function format_documentation(data)
  local edge = data.edge
  local member = edge.node
  local role = edge.role:sub(1, 1) .. edge.role:sub(2):lower()
  local documentation = role .. " of " .. data.org_name .. " org\n"
  if member.location ~= nil then
    documentation = documentation .. string.format("Located in %s\n", member.location)
  end
  if member.company ~= nil then
    documentation = documentation .. string.format("Works at %s\n", member.company)
  end
  local social_accounts = format_social_accounts(member.socialAccounts.nodes)
  if social_accounts ~= "" then
    documentation = documentation .. social_accounts .. "\n"
  end
  if member.bio ~= nil then
    documentation = documentation .. "\n" .. member.bio
  end
  return documentation
end

---@class cmp.gh.users.CompletionItem: lsp.CompletionItem
---@field data cmp.gh.users.CompletionItemData

---@class cmp.gh.users.CompletionItemData
---@field org_name string
---@field edge cmp.gh.users.OrgMemberEdge

---Format a single item for nvim-cmp
---@param edge cmp.gh.users.OrgMemberEdge
---@return cmp.gh.users.CompletionItem
local function format_item(edge)
  local member = edge.node
  local label = "@" .. member.login
  if member.name and member.name ~= "" then
    label = label .. " (" .. member.name .. ")"
  end
  return {
    label = label,
    insertText = "@" .. member.login,
    data = edge,
    cmp = {
      kind_hl_group = "CmpItemKindUser",
      kind_text = "User",
    },
    dup = 1,
  }
end

---Return whether this source is available in the current context or not (optional).
---@param self cmp.gh.users.Source
---@return boolean
function source:is_available()
  return true
end

---Return the debug name of this source (optional).
---@param self cmp.gh.users.Source
---@return string
function source:get_debug_name()
  return "GitHub users"
end

---Return LSP's PositionEncodingKind.
---NOTE: If this method is omitted, the default value will be `utf-16`.
---@param self cmp.gh.users.Source
---@return lsp.PositionEncodingKind
function source:get_position_encoding_kind()
  return "utf-16"
end

---Return the keyword pattern for triggering completion (optional).
---If this is omitted, nvim-cmp will use a default keyword pattern. See |cmp-config.completion.keyword_pattern|.
---@param self cmp.gh.users.Source
---@return string
function source:get_keyword_pattern()
  return [[\k\+]]
end

---Return trigger characters for triggering completion (optional).
---@param self cmp.gh.users.Source
---@return string[]
function source:get_trigger_characters()
  return { "@" }
end

---Invoke completion (required).
---@param self cmp.gh.users.Source
---@param ctx cmp.Context
---@param callback fun(response: lsp.CompletionResponse?)
function source:complete(_, callback)
  if self.fetching then
    -- We are already fetching the users, so we don't want to block the completion.
    -- We will call the callback specifying that it's not complete
    log("complete: Currently fetching users, returning empty list", vim.log.levels.DEBUG)
    callback()
  else
    local response = self.cache:get(self.github_owner)
    if response then
      log("complete: Returning cached response", vim.log.levels.DEBUG)
      callback(response)
    else
      log("complete: Fetching users", vim.log.levels.DEBUG)
      self:get_completion_response(callback)
      if self.cache:expired(self.github_owner) then
        log("complete: Cache expired, fetching users", vim.log.levels.DEBUG)
        -- Fetch the org members from GitHub to update the cache.
        -- We already presented the cached response to the user,
        -- but we want to update the cache for the next time.
        self:get_completion_response()
      end
    end
  end
end

---Fetch the org members from GitHub to build the completion response and optionally pass it to the callback.
---Persists the response to the cache.
---@param self cmp.gh.users.Source
---@param callback? fun(response: lsp.CompletionResponse?)
function source:get_completion_response(callback)
  self.fetching = true
  self.gh:org_members(self.github_owner, function(ok, results)
    local response = { items = {}, isIncomplete = false }
    if ok and results then
      if results.data.organization then
        local edges = results.data.organization.membersWithRole.edges
        for _, edge in ipairs(edges) do
          local completion_item = format_item(edge)
          completion_item.data = {
            org_name = results.data.organization.name,
            edge = edge,
          }
          table.insert(response.items, completion_item)
        end
      else
        log("get_completion_response: " .. self.github_owner .. " is not an organization", vim.log.levels.DEBUG)
      end
    end
    if callback then
      if type(callback) == "function" then
        callback(response)
      else
        error("callback must be a function")
      end
    end
    self.cache:set(self.github_owner, response)
    a.void(function()
      log("get_completion_response: saving cache to filesystem", vim.log.levels.DEBUG)
      self.cache:save()
      self.fetching = false
    end)()
  end)
end

---Resolve completion item (optional). This is called right before the completion is about to be displayed.
---Useful for setting the text shown in the documentation window (`completion_item.documentation`).
---@param self cmp.gh.users.Source
---@param completion_item cmp.gh.users.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:resolve(completion_item, callback)
  completion_item.documentation = {
    kind = "markdown",
    value = format_documentation(completion_item.data),
  }
  callback(completion_item)
end

---Executed after the item was selected.
---@param self cmp.gh.users.Source
---@param completion_item lsp.CompletionItem
---@param callback fun(completion_item: lsp.CompletionItem|nil)
function source:execute(completion_item, callback)
  callback(completion_item)
end

return {
  ---Return a new instance of this source.
  ---Accepts a cache for dependency injection which is useful for testing.
  ---@param github_owner string The GitHub owner (user or organization)
  ---@param cache cmp.gh.users.Cache
  ---@param config? cmp.gh.users.Source.Config
  ---@return cmp.gh.users.Source
  new = function(github_owner, cache, config)
    config = vim.tbl_deep_extend("force", default_config, config or {})
    local self = {
      cache = cache,
      fs = config.fs,
      gh = config.gh,
      github_owner = github_owner,
    }
    self = setmetatable(self, { __index = source })
    return self
  end
}
