local cfg = require("cmp-gh-users.config").get()
local log = require("cmp-gh-users.logger").new("cmp-gh-users.cache", cfg.log_level)

return {
  ---Create a new instance of the cache.
  ---@param cache_file string
  ---@param max_age number Maximum age of a cache item in seconds
  ---@param fs cmp.gh.users.cache.Fs
  new = function(cache_file, max_age, fs)
    ---@class cmp.gh.users.Cache
    ---Provides a cache for completion responses, can be persisted to the filesystem and loaded from it, in an asyncronous fashion.
    local cache = {}

    local cache_dir = vim.fs.dirname(cache_file)

    ---@alias cmp.gh.users.CacheItems table<string, cmp.gh.users.CacheItem>
    ---@type cmp.gh.users.CacheItems
    local entries = {}

    ---Get a cache item by key. Returns nil if the item does not exist.
    ---@param key string
    ---@return lsp.CompletionResponse?
    function cache:get(key)
      log("get key=" .. key, vim.log.levels.DEBUG)
      local entry = entries[key]
      if entry == nil then
        return nil
      end
      return entry.value
    end

    ---Check if a cache item exists and is older than `max_age`.
    ---If the item doesn't exist, it is considered expired.
    ---@param key string
    ---@return boolean
    function cache:expired(key)
      local entry = entries[key]
      if entry == nil then
        return true
      end
      local is_expired = os.time() - entry.last_update > max_age
      log("expired key=" .. key .. " expired=" .. tostring(is_expired), vim.log.levels.DEBUG)
      return is_expired
    end

    ---Save a completion response to the cache. The timestamp of the last fetch is set to the current time.
    ---If the cache item already exists, it will be overwritten.
    ---@param self cmp.gh.users.Cache
    ---@param key string
    ---@param value lsp.CompletionResponse
    ---@return nil
    function cache:set(key, value)
      log("set key=" .. key, vim.log.levels.DEBUG)
      ---@class cmp.gh.users.CacheItem
      ---@field last_update number The timestamp of the last update in seconds since epoch
      ---@field value lsp.CompletionResponse
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
        log("loaded successfully", vim.log.levels.DEBUG)
      end
      return nil
    end

    ---Save the cache to the filesystem.
    ---This method must be called within an async context.
    ---@param self cmp.gh.users.Cache
    ---@return nil|string Error message if saving failed
    function cache:save()
      log("save", vim.log.levels.DEBUG)
      if not fs.dir_exists(cache_dir) then
        local err, ok = fs.mkdirs(cache_dir)
        if err then
          return err
        end
        if not ok then
          log("failed to create cache directory", vim.log.levels.DEBUG)
          return "failed to create cache directory"
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
