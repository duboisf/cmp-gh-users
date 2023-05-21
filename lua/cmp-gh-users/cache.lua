local cfg = require("cmp-gh-users.config").get()
local log = require("cmp-gh-users.logger").new("cmp-gh-users.cache", cfg.log_level)

---@alias cmp.gh.users.CacheItems table<string, cmp.gh.users.CacheItem>

---@class cmp.gh.users.Cache
---@field private config cmp.gh.users.Config.Cache
---@field private entries cmp.gh.users.CacheItems
---@field private fs cmp.gh.users.Fs
---Provides a cache for completion responses, can be persisted to the filesystem and loaded from it, in an asyncronous fashion.
local cache = {}

---@class cmp.gh.users.Cache.Config
local default_config = {
  config = cfg.cache,
  ---Used to persist the cache to the filesystem. Defaults to the fs module.
  ---Can be overridden for testing purposes.
  fs = require("cmp-gh-users.fs"),
}

---Get a cache item by key. Returns nil if the item does not exist.
---@param key string
---@return lsp.CompletionResponse?
function cache:get(key)
  log("get key=" .. key, vim.log.levels.DEBUG)
  local entry = self.entries[key]
  if entry == nil then
    return nil
  end
  return entry.value
end

---Save a completion response to the cache. The timestamp of the last fetch is set to the current time.
---If the cache item already exists, it will be overwritten.
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
  self.entries[key] = cache_item
end

---Check if a cache item exists and is older than `max_age`.
---If the item doesn't exist, it is considered expired.
---@param self cmp.gh.users.Cache
---@param key string
---@return boolean
function cache:expired(key)
  local entry = self.entries[key]
  if entry == nil then
    return true
  end
  local is_expired = os.time() - entry.last_update > self.config.max_age
  log("key=" .. key .. " expired=" .. tostring(is_expired), vim.log.levels.DEBUG)
  return is_expired
end

---Load the cache from the filesystem.
---This method must be called within an async context.
---@param self cmp.gh.users.Cache
---@return nil|string
function cache:load()
  log("load from path " .. self.config.path, vim.log.levels.DEBUG)
  local err, data = self.fs.read_file(self.config.path)
  if err then
    if not err:match("ENOENT") then
      log("failed to load: " .. err, vim.log.levels.DEBUG)
    end
    return err
  end
  ---@type boolean, cmp.gh.users.CacheItems?
  local ok, parsed = pcall(vim.json.decode, data, { luanil = { object = true, array = true } })
  if ok and parsed ~= nil then
    self.entries = parsed
    log("loaded successfully", vim.log.levels.DEBUG)
  else
    log("failed to parse data", vim.log.levels.DEBUG)
  end
  return nil
end

---Save the cache to the filesystem.
---This method must be called within an async context.
---@param self cmp.gh.users.Cache
---@return nil|string Error message if saving failed
function cache:save()
  log("save", vim.log.levels.DEBUG)
  local cache_dir = vim.fs.dirname(self.config.path)
  if not self.fs.dir_exists(cache_dir) then
    local err, ok = self.fs.mkdirs(cache_dir)
    if err then
      return err
    end
    if not ok then
      log("failed to create cache directory", vim.log.levels.DEBUG)
      return "failed to create cache directory"
    end
  end
  local marshaled_entries = vim.json.encode(self.entries)
  return self.fs.write_file(self.config.path, marshaled_entries)
end

return {
  ---Create a new instance of the cache.
  ---@param config? cmp.gh.users.Cache.Config The configuration for the cache.
  ---@return cmp.gh.users.Cache
  new = function(config)
    config = vim.tbl_deep_extend("force", default_config, config or {})

    local mt = {
      __index = cache,
      __tostring = function()
        return "cmp.gh.users.Cache"
      end,
    }

    local self = setmetatable({
      ---@type cmp.gh.users.Config.Cache
      config = config.config,
      entries = {},
      fs = config.fs,
    }, mt)

    return self
  end,
}
