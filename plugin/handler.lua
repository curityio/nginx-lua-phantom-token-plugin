--
-- The Kong entry point handler
--

local access = require "kong.plugins.phantom-token.access"

-- See https://github.com/Kong/kong/discussions/7193 for more about the PRIORITY field
local PhantomToken = {
    PRIORITY = 1000,
    VERSION = "2.0.1",
}

function PhantomToken:access(conf)
    access.run(conf)
end

return PhantomToken
