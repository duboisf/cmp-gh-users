describe("parse_git_remote", function()
  local GitHub = require("cmp-gh-users.github")
  local gh = GitHub.new()

  it("parses an https github repo url correctly", function()
    -- Given
    local url = "https://github.com/duboisf/cmp-gh-users.git"

    -- When
    local remote = gh:parse_git_remote(url)

    -- Then
    assert(remote, "remote is not nil")
    assert.is.equal("duboisf", remote.owner)
    assert.is.equal("cmp-gh-users", remote.repo)
  end)

  it("parses an ssh github repo url correctly", function()
    -- Given
    local url = "git@github.com:duboisf/cmp-gh-users.git"

    -- When
    local remote = gh:parse_git_remote(url)

    -- Then
    assert(remote, "remote is not nil")
    assert.is.equal("duboisf", remote.owner)
    assert.is.equal("cmp-gh-users", remote.repo)
  end)

  it("returns a nil remote when the url is not a github repo", function()
    -- Given
    local url = "https://gitlab.com/duboisf/cmp-gh-users.git"

    -- When
    local remote = gh:parse_git_remote(url)

    -- Then
    assert.is_nil(remote)
  end)

  it("returns a GitHub remote that can be converted to a string", function()
    -- Given
    local url = "https://github.com/duboisf/cmp-gh-users.git"

    -- When
    local remote = gh:parse_git_remote(url)
    local str = tostring(remote)

    -- Then
    assert.is.equal("GitHubRemote(owner=duboisf, repo=cmp-gh-users)", str)
  end)
end)

describe("with_remote", function()
  local GitHub = require("cmp-gh-users.github")

  it("returns a GitHub.Remote when the cwd is inside a github repo", function()
    -- Given
    local mock_git = {
      remote = function(_, callback)
        callback("https://github.com/duboisf/cmp-gh-users.git")
      end,
    }
    local gh = GitHub.new(mock_git, nil)

    -- When
    local co = coroutine.create(function()
      gh:with_remote(function(remote)
        coroutine.yield(remote)
      end)
    end)

    ---@type boolean, cmp.gh.users.GitHub.Remote?
    local success, remote = coroutine.resume(co)

    -- Then
    assert(success, "coroutine did not succeed")
    assert(remote, "remote is not nil")
    assert.is.equal("duboisf", remote.owner)
    assert.is.equal("cmp-gh-users", remote.repo)
  end)

  it("returns nil if the cwd is not inside a github repo", function()
    -- Given
    local mock_git = {
      remote = function(_, callback)
        callback("https://gitlab.com/duboisf/cmp-gh-users.git")
      end,
    }
    local gh = GitHub.new(mock_git, nil)

    -- When
    local co = coroutine.create(function()
      gh:with_remote(function(remote)
        coroutine.yield(remote)
      end)
    end)

    ---@type boolean, cmp.gh.users.GitHub.Remote?
    local success, remote = coroutine.resume(co)

    -- Then
    assert(success, "coroutine did not succeed")
    assert.is_nil(remote)
  end)

  it("returns nil if the cwd is not even a git repo", function()
    -- Given
    local mock_git = {
      remote = function(_, callback)
        callback(nil)
      end,
    }
    local gh = GitHub.new(mock_git, nil)

    -- When
    local co = coroutine.create(function()
      gh:with_remote(function(remote)
        coroutine.yield(remote)
      end)
    end)

    ---@type boolean, cmp.gh.users.GitHub.Remote?
    local success, remote = coroutine.resume(co)

    -- Then
    assert(success, "coroutine did not succeed")
    assert.is_nil(remote)
  end)
end)
