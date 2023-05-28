local healh = {}

local uv = vim.loop

---@param cmd string
---@param args string[]
---@return boolean ok, string output
local function sync_spawn(cmd, args)
  ---@type string[]
  local results = {}
  local exit_code = -1
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  ---@type uv_process_t|nil
  local handle
  handle = uv.spawn(cmd, {
    args = args,
    stdio = { nil, stdout, stderr },
  }, function(code)
    if handle then
      handle:close()
    end
    exit_code = code
  end)

  if stdout then
    stdout:read_start(function(err, data)
      assert(not err, err)
      if data then
        table.insert(results, data)
      end
    end)
  end
  if stderr then
    stderr:read_start(function(err, data)
      assert(not err, err)
      if data then
        table.insert(results, data)
      end
    end)
  end
  vim.wait(2000, function()
    return exit_code ~= -1
  end, 10, true)
  return exit_code == 0, table.concat(results, "\n")
end

---Check if a binary is installed
---@param name string
---@param args string[]
local function report_binary(name, args)
  local ok, output = sync_spawn(name, args)
  if ok then
    vim.health.report_ok(vim.trim(output))
  else
    vim.health.report_error(name, "not installed")
  end
end

function healh.check()
  local co, is_main = coroutine.running()
  print("co", co, "is_main", is_main)
  local ok = false
  ok, _ = pcall(require, "cmp")
  if ok then
    vim.health.report_ok("cmp is installed")
  else
    vim.health.report_error("cmp", "You must install the nvim-cmp plugin")
  end

  report_binary("git", { "--version" })
  report_binary("gh", { "--version" })
  local output = ""
  ok, output = sync_spawn("gh", { "auth", "status" })
  if ok then
    vim.health.report_ok("gh auth status\n" .. vim.trim(output))
  else
    vim.health.report_error("gh auth status", "not logged in")
  end
end

return healh
