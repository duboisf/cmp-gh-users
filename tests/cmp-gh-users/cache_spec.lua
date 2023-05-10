describe("cache", function()
  it("can save a cache item", function()
    local Cache = require("cmp-gh-users.cache")
    -- Given
    -- local cache = Cache.new("not important", 1, {})
    --
    -- -- When
    -- local cache_item = { isComplete = false, items = {} }
    -- cache:set("some_owner", cache_item)
    -- local actual_cache_item = cache:get("some_owner")
    --
    -- -- Then
    -- if actual_cache_item == nil then
    --   error("Cache item is nil")
    -- end
    -- assert.are.equal(cache_item, actual_cache_item)
  end)
end)
