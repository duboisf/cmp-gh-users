local GitHub = require("cmp-gh-users.github")
local cfg = require("cmp-gh-users.config").get()
local log = require("cmp-gh-users.logger").new("cmp-gh-users.source", cfg.log_level)

---@alias BufferNumber number

---@class cmp.gh.users.Source
---@field private cache cmp.gh.users.Cache
---@field private github_owner string
---@field private gh cmp.gh.users.GitHub
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
---@param params cmp.SourceCompletionApiParams
---@param callback fun(response: lsp.CompletionResponse?)
function source:complete(params, callback)
  if not vim.tbl_contains(cfg.filetypes, params.context.filetype) then
    callback()
  else
    local response = self.cache:get(self.github_owner)
    if response then
      log("complete: returning cached response", vim.log.levels.DEBUG)
      callback(response)
    else
      callback()
    end
  end
end

---Format the users for display in the completion menu.
---@param org_name string The name of the GitHub organization.
---@param users cmp.gh.users.OrgMemberEdge[]
---@return lsp.CompletionItem[]
local function format_users(org_name, users)
  ---@type lsp.CompletionItem[]
  local items = {}
  for _, edge in ipairs(users) do
    local member = edge.node
    local label = "@" .. member.login
    if member.name and member.name ~= "" then
      label = label .. " (" .. member.name .. ")"
    end
    local doc = ""
    local role = edge.role:sub(1, 1) .. edge.role:sub(2):lower()
    doc = role .. " of " .. org_name .. " org\n"
    if member.location ~= nil then
      doc = doc .. string.format("Located in %s\n", member.location)
    end
    if member.company ~= nil then
      doc = doc .. string.format("Works at %s\n", member.company)
    end
    local social_accounts = format_social_accounts(member.socialAccounts.nodes)
    if social_accounts ~= "" then
      doc = doc .. social_accounts .. "\n"
    end
    if member.bio ~= nil then
      doc = doc .. "\n" .. member.bio
    end
    table.insert(items, {
      documentation = doc,
      label = label,
      insertText = "@" .. member.login,
      cmp = {
        kind_hl_group = "CmpItemKindUser",
        kind_text = "User",
      },
      dup = 1,
    })
  end
  return items
end

---Format the teams for display in the completion menu.
---@param org_name string The name of the GitHub organization.
---@param teamEdges cmp.gh.users.TeamEdge[]
---@return lsp.CompletionItem[]
local function format_teams(org_name, teamEdges)
  ---@type lsp.CompletionItem[]
  local items = {}
  for _, teamEdge in ipairs(teamEdges) do
    local team = teamEdge.node
    local doc = team.name .. "\n\n"
    doc = doc .. "Team part of the " .. org_name .. " org"
    if team.description ~= nil then
      doc = doc .. "\n\n" .. team.description
    end
    table.insert(items, {
      documentation = doc,
      label = "@" .. team.combinedSlug,
      insertText = "@" .. team.combinedSlug,
      cmp = {
        kind_hl_group = "CmpItemKindTeam",
        kind_text = "Team",
      },
      dup = 1,
    })
  end
  return items
end

---Fetch the org users and teams from GitHub to build the completion response.
---Persists the response to the cache.
---@param self cmp.gh.users.Source
---@param callback fun() The callback to invoke when the response is ready.
function source:prepare_completion_response(callback)
  coroutine.wrap(function()
    local co = coroutine.running()

    self.gh:org_members(self.github_owner, function(ok, result)
      local members = {}
      if ok and result.data.organization then
        members = result.data.organization.membersWithRole.edges
      end
      coroutine.resume(co, "members", members)
    end)

    self.gh:org_teams(self.github_owner, function(ok, result)
      local teams = {}
      if ok and result.data.organization then
        teams = result.data.organization.teams.edges
      end
      coroutine.resume(co, "teams", teams)
    end)

    ---@type {members: cmp.gh.users.OrgMemberEdge[], teams: cmp.gh.users.TeamEdge[]}
    local results = {}

    local function parse_yield(type, result)
      log("parse_completion_response: parsing " .. type .. " response", vim.log.levels.DEBUG)
      results[type] = result
    end

    log("parse_completion_response: waiting for responses", vim.log.levels.DEBUG)
    parse_yield(coroutine.yield())
    log("parse_completion_response: waiting for responses", vim.log.levels.DEBUG)
    parse_yield(coroutine.yield())

    local response = { items = {}, isIncomplete = false }

    response.items = format_users(self.github_owner, results.members)
    local team_items = format_teams(self.github_owner, results.teams)

    for _, team_item in ipairs(team_items) do
      table.insert(response.items, team_item)
    end

    self.cache:set(self.github_owner, response)

    callback()
  end)()
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
