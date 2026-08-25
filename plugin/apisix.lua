local core = require "apisix.core"
local access = require("apisix.plugins.phantom-token.access")

local _M = {
    version = 3.0,
    priority = 1000,
    name = "phantom-token",
    schema = {
        type = "object",
        properties = {}
    }
}

function _M.access(conf, ctx)
    access.run(conf)
end

return _M
