local logger = {}

---Log a message.
---@param module string The lua module name.
---@param min_level number The minimum log level, see `:help vim.log.levels`.
---@param msg string The message to log.
---@param lvl number The log level, see `:help vim.log.levels`.
local function log(module, min_level, msg, lvl)
  if lvl < min_level then
    return
  end
  local current_time = os.date("%H:%M:%S")
  msg = string.format("%s: %s: %s", current_time, module, msg)
  local logit = function()
    vim.notify(msg, lvl)
  end
  (vim.in_fast_event() and vim.schedule_wrap(logit) or logit)()
end

---Create a new logger.
---Returns a function that logs a message.
---The minimum log level to log is set by the `min_level` parameter.
---@param module string The lua module name.
---@param min_level number The minimum log level, see `:help vim.log.levels`.
function logger.new(module, min_level)
  assert(type(module) == "string", "module must be a string")
  assert(type(min_level) == "number", "min_level must be a number")
  --Log a message.
  ---@param msg string The message to log.
  ---@param lvl number The log level, see `:help vim.log.levels`.
  return function(msg, lvl)
    assert(type(msg) == "string", "msg must be a string")
    assert(type(lvl) == "number", "lvl must be a number")
    log(module, min_level, msg, lvl)
  end
end

return logger
