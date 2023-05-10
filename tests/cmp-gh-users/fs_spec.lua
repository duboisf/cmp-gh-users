describe("fs.dir_exists when the directory exists", function()
  local a = require("plenary.async")
  local fs = require("cmp-gh-users.fs")

  it("returns nil and true", function()
    local err, exists, done
    a.void(function()
      err, exists = fs.dir_exists("tests/cmp-gh-users")
      done = true
    end)()
    vim.wait(1000, function() return done end)
    assert.are.falsy(err)
    assert.are.equal(true, exists)
  end)
end)
