local cfg = require("cmp-gh-users.config").get()
local log = require("cmp-gh-users.logger").new("cmp-gh-users.fs", cfg.log_level)

---@class cmp.gh.users.Fs
---Contains filesystem related functions.
---Leverages the plenary.async library, so these functions must be called within an async context (e.g. `a.run()`).
local fs = {}

local a = require("plenary.async")

---Read the filename `path`.
---On success, returns nil and the data from the file as a string.
---On error, returns the error as a string.
---Uses plenary.async so must be called within an async context.
---@param path string
---@return nil|string err, string|nil data
function fs.read_file(path)
  log("read_file path=" .. path, vim.log.levels.DEBUG)
  local err
  local fd
  ---@type nil|string, integer|nil
  err, fd = a.uv.fs_open(path, "r", 438)
  if err or fd == nil then
    return "failed to open file: " .. tostring(err), nil
  end
  local stat
  ---@type nil|string, {size: integer}|nil
  err, stat = a.uv.fs_stat(path)
  if err or stat == nil then
    return "failed to stat file: " .. tostring(err), nil
  end
  local data
  ---@type nil|string, string|nil
  err, data = a.uv.fs_read(fd, stat.size)
  if err or data == nil then
    return "failed to read file: " .. tostring(err), nil
  end
  local success
  ---@type nil|string, boolean|nil
  err, success = a.uv.fs_close(fd)
  if err or not success then
    return "failed to close file: " .. tostring(err), nil
  end
  return nil, data
end

---Writes `data` to the filename `path`.
---Returns nil on success or an error message.
---Uses plenary.async so must be called within an async context.
---@param path string
---@param data string
---@return nil|string err
function fs.write_file(path, data)
  ---@type nil|string, integer|nil
  local err, fd = a.uv.fs_open(path, "w+", 438)
  if err or fd == nil then
    return "failed to open file: " .. tostring(err)
  end
  local bytes
  ---@type nil|string, integer|nil
  err, bytes = a.uv.fs_write(fd, data, 0)
  if err or bytes == nil then
    return "failed to write file: " .. tostring(err)
  end
end

---Returns a tuple: nil on success or an error message, and a boolean indicating whether the directory exists
---Must be called within an async context.
---@param path string
---@return nil|string err, boolean exists
function fs.dir_exists(path)
  ---@type nil|string, {type: string}|nil
  local err, stat = a.uv.fs_stat(path)
  if err then
    -- ENOENT: no such file or directory
    if err:match("ENOENT") then
      return nil, false
    end
    return err, false
  end
  if stat == nil then
    return "path '" .. path .. "' exists but stat returned nil", false
  end
  if stat.type ~= "directory" then
    return "path '" .. path .. "' exists but is a " .. stat.type .. ", not a directory", false
  end
  return nil, stat.type == "directory"
end

---Creates the directory `path` and any parent directories.
---Must be called within an async context.
---@return nil|string err, boolean created
function fs.mkdirs(path)
  local err, exists = fs.dir_exists(path)
  if err then
    return "could not check if directory '" .. path .. "' exists: " .. err, false
  end
  if exists then
    -- recursion base case: directory already exists
    return nil, true
  end
  -- make sure to create all parent directories first through recursion
  local parent = vim.fs.dirname(path)
  local success
  err, success = fs.mkdirs(parent)
  if err or not success then
    return "failed to create parent directory '" .. parent .. "': " .. tostring(err), false
  end
  -- since parent directories were created, this should succeed
  return a.uv.fs_mkdir(path, 511)
end

return fs
