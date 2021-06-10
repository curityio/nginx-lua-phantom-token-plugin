local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.phantom-token.access"

local TokenHandler = BasePlugin:extend()
TokenHandler.PRIORITY = 1000

function TokenHandler:new()
    TokenHandler.super.new(self, "phantom-token")
end

function TokenHandler:access(conf)
    TokenHandler.super.access(self)
    access.run(conf)
end

return TokenHandler