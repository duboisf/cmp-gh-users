---@class cmp.gh.users.GitHubApi
---Client for querying the GitHub API.
---Relies on the `gh` command-line tool being installed.
local github = {}

local Job = require("plenary.job")
local cfg = require("cmp-gh-users.config"):get()
local git = require("cmp-gh-users.git")
local log = require("cmp-gh-users.logger").new("cmp-gh-users.github", cfg.log_level)

local graphql_query = [[
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
---@field organization cmp.gh.users.Organization?

---@class cmp.gh.users.Organization
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

---Gets the members of a GitHub organization.
---@param org_name string The name of the GitHub organization
---@param callback fun(ok: boolean, result: cmp.gh.users.OrgMembersQueryResult?)
function github.org_members(org_name, callback)
  log("querying org members for " .. org_name, vim.log.levels.DEBUG)
  local job = Job:new({
    "gh",
    "api",
    "--paginate",
    "graphql",
    "-F",
    "org=" .. org_name,
    "-f",
    "query=" .. graphql_query,
    on_exit = function(job)
      -- try to parse the result regardless of the exit code
      -- because in the case of a non-zero exit code, it might
      -- return a json response with an error message
      local ok, parsed = pcall(
        vim.json.decode,
        job:result()[1],
        { luanil = { object = true, array = true } }
      )
      log("org members query success? " .. tostring(ok), vim.log.levels.DEBUG)
      callback(ok, parsed)
    end,
  })
  job:start()
end

---Parses a git remote.
---@param remote string The remote URL, given by `git remote get-url --push <remote>`.
---@return cmp.gh.users.GitHubRemote|nil
function github.parse_git_remote(remote)
  if not (remote:match("^git@github.com:") or remote:match("^https://github.com/")) then
    return nil
  end
  remote = string.gsub(remote, ".git$", "")
  local owner, repo = remote:match("github.com.(.+)/(.+)")
  ---@class cmp.gh.users.GitHubRemote
  local GitHubRemote = {
    ---The owner of the GitHub repository.
    owner = owner,
    ---The name of the GitHub repository.
    repo = repo,
  }
  GitHubRemote = setmetatable(GitHubRemote, {
    __tostring = function(self)
      return string.format("GitHubRemote(owner=%s, repo=%s)", self.owner, self.repo)
    end,
  })
  return GitHubRemote
end

---Do something when cwd is inside a GitHub repo.
---
---The callback is only called when the current working
---directory is inside a git repository that has a remote
---named `origin` which is a GitHub repository.
---@param callback fun(remote: cmp.gh.users.GitHubRemote)
---@return nil
function github.when_in_github_repo(callback)
  git.remote("origin", function(remote)
    local github_remote = github.parse_git_remote(remote)
    if github_remote then
      log("cwd inside github repo, " .. tostring(github_remote), vim.log.levels.DEBUG)
      callback(github_remote)
    end
  end)
end

return github
