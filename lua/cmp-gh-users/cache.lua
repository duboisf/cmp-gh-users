---@alias cmp.gh.users.CacheKey string
---@alias cmp.gh.users.CacheItems table<cmp.gh.users.CacheKey, cmp.gh.users.CacheItem>

---@class cmp.gh.users.CacheItem
---@field last_update number The timestamp of the last update in seconds since epoch
---@field value lsp.CompletionResponse

---@class cmp.gh.users.cache.Fs
---@field read_file fun(path: string): nil|string, string|nil Read the filename `path`. On success, returns nil and the data from the file as a string. On error, returns the error as a string. Must be called within an async context
---@field write_file fun(path: string, data: string): nil|string Writes `data` to the filename `path`. Returns nil on success or an error message. Must be called with an async context
---@field dir_exists fun(path: string): nil|string, boolean|nil Returns a tuple: nil on success or an error message, and a boolean indicating whether the directory exists
---@field mkdirs fun(path: string): nil|string, boolean|nil Returns a tuple: nil on success or an error message, and a boolean indicating whether the directory was created successfully

return {
  ---Create a new instance of the cache.
  ---@param cache_file string
  ---@param max_age number Maximum age of a cache item in seconds
  ---@param fs cmp.gh.users.cache.Fs
  new = function(cache_file, max_age, fs)
    local cache_dir = vim.fs.dirname(cache_file)

    ---@class cmp.gh.users.Cache
    local cache = {}

    ---@type cmp.gh.users.CacheItems
    local entries = {}

    ---Get a cache item by key. Returns nil if the item does not exist or is older than `max_age`.
    ---@param key cmp.gh.users.CacheKey
    ---@return lsp.CompletionResponse?
    function cache:get(key)
      local entry = entries[key]
      if entry == nil then
        return nil
      end
      if os.time() - entry.last_update > max_age then
        return nil
      end
      return entry.value
    end

    ---Save a completion response to the cache. The timestamp of the last fetch is set to the current time.
    ---If the cache item already exists, it will be overwritten.
    ---@param self cmp.gh.users.Cache
    ---@param key cmp.gh.users.CacheKey
    ---@param value lsp.CompletionResponse
    ---@return nil
    function cache:set(key, value)
      local cache_item = {
        last_update = os.time(),
        value = value,
      }
      entries[key] = cache_item
    end

    ---Load the cache from the filesystem.
    ---This method must be called within an async context.
    ---@param self cmp.gh.users.Cache
    ---@return nil|string
    function cache:load()
      local err, data = fs.read_file(cache_file)
      if err then
        return err
      end
      ---@type boolean, cmp.gh.users.CacheItems?
      local ok, parsed = pcall(vim.json.decode, data, { luanil = { object = true, array = true } })
      if ok and parsed ~= nil then
        entries = parsed
      end
      return nil
    end

    ---Save the cache to the filesystem.
    ---This method must be called within an async context.
    ---@param self cmp.gh.users.Cache
    ---@return nil|string Error message if saving failed
    function cache:save()
      if not fs.dir_exists(cache_dir) then
        local err, ok = fs.mkdirs(cache_dir)
        if err then
          return err
        end
        if not ok then
          return "Failed to create cache directory"
        end
      end
      ---@type string
      ---@diagnostic disable-next-line: assign-type-mismatch
      local marshaled_entries = vim.json.encode(entries)
      return fs.write_file(cache_file, marshaled_entries)
    end

    local self = setmetatable({}, { __index = cache })
    return self
  end,
}
