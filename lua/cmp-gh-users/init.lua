local init = {}

local cfg = require("cmp-gh-users.config")

---@param user_config? cmp.gh.users.Config
function init.setup(user_config)
  cfg.set(user_config or {})
end

return init
