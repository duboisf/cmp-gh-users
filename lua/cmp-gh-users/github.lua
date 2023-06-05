---Module for wrapping the `gh` cli.
---Offer various GitHub related functionality like querying the GitHub API,
---parsing GitHub remotes, checking if we're in a GitHub repository, etc.
---Relies on the `gh` command-line tool being installed.
---@class cmp.gh.users.GitHub
---@field git cmp.gh.users.Git
---@field Job Job
local github = {}

local cfg = require("cmp-gh-users.config"):get()
local log = require("cmp-gh-users.logger").new("cmp-gh-users.github", cfg.log_level)

local graphql_users_query = [[
  query ($org: String!, $endCursor: String) {
    organization(login: $org) {
      name
      membersWithRole(first: 100, after: $endCursor) {
        edges {
          node {
            login
            name
            bio
            location
            company
            socialAccounts(first:20) {
              nodes {
                displayName
                provider
                url
              }
            }
            status {
              emojiHTML
              indicatesLimitedAvailability
              message
            }
          }
          role
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
]]

---@class cmp.gh.users.OrgMembersQueryResult
---@field data cmp.gh.users.OrgMembersQueryResultData

---@class cmp.gh.users.OrgMembersQueryResultData
---@field organization cmp.gh.users.OrganizationMembers?

---@class cmp.gh.users.OrganizationMembers
---@field name string The name of the organization
---@field membersWithRole cmp.gh.users.OrgMemberConnection

---@class cmp.gh.users.OrgMemberConnection
---@field edges cmp.gh.users.OrgMemberEdge[]
---@field pageInfo cmp.gh.users.PageInfo

---@class cmp.gh.users.PageInfo
---@field hasNextPage boolean
---@field endCursor? string

---@alias cmp.gh.users.Role
---| "ADMIN"
---| "MEMBER"

---@class cmp.gh.users.OrgMemberEdge
---@field node cmp.gh.users.User
---@field role cmp.gh.users.Role

---@class cmp.gh.users.User
---@field login string
---@field name string?
---@field bio string?
---@field location string?
---@field company string?
---@field socialAccounts cmp.gh.users.SocialAccounts
---@field status cmp.gh.users.Status

---@class cmp.gh.users.Status
---@field emojiHTML string?
---@field indicatesLimitedAvailability boolean
---@field message string?

---@class cmp.gh.users.SocialAccounts
---@field nodes cmp.gh.users.SocialAccount[]

---@class cmp.gh.users.SocialAccount
---@field displayName string
---@field provider string
---@field url string

---Execute a GraphQL query against the GitHub API.
---@param query string The GraphQL query to execute
---@param org_name string The name of the GitHub organization
---@param callback fun(ok: boolean, result: any)
function github:graphql(query, org_name, callback)
  local job = self.Job:new({
    "gh",
    "api",
    "--paginate",
    "graphql",
    "-F",
    "org=" .. org_name,
    "-f",
    "query=" .. query,
    on_exit = function(job)
      -- try to parse the result regardless of the exit code
      -- because in the case of a non-zero exit code, it might
      -- return a json response with an error message
      local ok, parsed = pcall(
        vim.json.decode,
        job:result()[1],
        { luanil = { object = true, array = true } }
      )
      callback(ok, parsed)
    end,
  })
  job:start()
end

---Gets the members of a GitHub organization.
---@param org_name string The name of the GitHub organization
---@param callback fun(ok: boolean, result: cmp.gh.users.OrgMembersQueryResult?)
function github:org_members(org_name, callback)
  log("querying org members for " .. org_name, vim.log.levels.DEBUG)
  self:graphql(graphql_users_query, org_name, callback)
end

local graphql_teams_query = [[
  query($org: String!, $endCursor: String) {
    organization(login: $org) {
      name
      teams(first:100, after: $endCursor) {
        edges {
          node {
            name,
            combinedSlug,
            description
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
]]

---@class cmp.gh.users.OrgTeamsQueryResult
---@field data cmp.gh.users.OrgTeamsQueryResultData

---@class cmp.gh.users.OrgTeamsQueryResultData
---@field organization cmp.gh.users.OrganizationTeams?
--
---@class cmp.gh.users.OrganizationTeams
---@field name string The name of the organization
---@field teams cmp.gh.users.TeamConnection
--
---@class cmp.gh.users.TeamConnection
---@field edges cmp.gh.users.TeamEdge[]
---@field pageInfo cmp.gh.users.PageInfo
--
---@class cmp.gh.users.TeamEdge
---@field node cmp.gh.users.Team
--
---@class cmp.gh.users.Team
---@field name string The name of the team
---@field combinedSlug string The slug corresponding to the organization and team
---@field description string The description of the team

---Gets the teams of a GitHub organization.
---@param org_name string The name of the GitHub organization
---@param callback fun(ok: boolean, result: cmp.gh.users.OrgTeamsQueryResult?)
function github:org_teams(org_name, callback)
  log("querying org teams for " .. org_name, vim.log.levels.DEBUG)
  self:graphql(graphql_teams_query, org_name, callback)
end

local Remote = {}

---Creates a new GitHubRemote.
---@param owner string The owner of the GitHub repository.
---@param repo string The name of the GitHub repository.
---@return cmp.gh.users.GitHub.Remote
function Remote.new(owner, repo)
  local mt = {
    __tostring = function(self)
      return string.format("GitHubRemote(owner=%s, repo=%s)", self.owner, self.repo)
    end,
  }
  ---Describes a GitHub remote.
  ---@class cmp.gh.users.GitHub.Remote
  ---@field owner string The owner of the GitHub repository.
  ---@field repo string The name of the GitHub repository.
  return setmetatable({ owner = owner, repo = repo }, mt)
end

---Parses a git remote. Returns nil if the given remote is not a GitHub remote.
---@param remote string The remote URL, given by `git remote get-url --push <remote>`.
---@return cmp.gh.users.GitHub.Remote|nil
function github:parse_git_remote(remote)
  if not (remote:match("^git@github.com:") or remote:match("^https://github.com/")) then
    return nil
  end
  remote = string.gsub(remote, ".git$", "")
  local owner, repo = remote:match("github.com.(.+)/(.+)")
  return Remote.new(owner, repo)
end

---Call the supplied callback with the GitHub remote if the current
---directory is inside a git repository that has a remote
---named `origin` which is a GitHub repository.
---Otherwise, call the callback with `nil`.
---@param callback fun(remote: cmp.gh.users.GitHub.Remote|nil)
---@return nil
function github:with_remote(callback)
  self.git.remote("origin", function(remote)
    if remote then
      local github_remote = github:parse_git_remote(remote)
      if github_remote then
        log("cwd inside github repo, " .. tostring(github_remote), vim.log.levels.DEBUG)
        callback(github_remote)
      end
    else
      callback(nil)
    end
  end)
end

return {
  ---Creates a new `cmp.gh.users.GitHub` instance.
  ---Accepts optional `git` and `Job` modules for dependency injection, which is useful for testing.
  ---If not provided, the default modules will be used.
  ---@param git? cmp.gh.users.Git
  ---@param Job? Job
  ---@return cmp.gh.users.GitHub
  new = function(git, Job)
    local self = setmetatable({}, { __index = github })

    self.git = git or require("cmp-gh-users.git")
    self.Job = Job or require("plenary.job")

    return self
  end
}
