local M = {}
local Job = require("plenary.job")
local parse = require("cmp-gh-users.parser")
local git = require("cmp-gh-users.git")

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
---| ""ADMIN""
---| ""MEMBER""

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

---@param org_name string
---@param callback fun(ok: boolean, result: cmp.gh.users.OrgMembersQueryResult?)
function M.org_users(org_name, callback)
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
      callback(ok, parsed)
    end,
  })
  job:start()
end

---Do something when cwd is inside a GitHub repo.
---
---The callback is only called when the current working
---directory is inside a git repository that has a remote
---named `origin` that is a GitHub repository.
---@param callback fun(remote: cmp.gh.users.GitHubRemoteUrl)
---@return nil
function M.when_in_github_repo(callback)
  git.remote("origin", function(remote)
    local parsed = parse.github_remote_line(remote)
    if parsed then
      callback(parsed)
    end
  end)
end

return M
