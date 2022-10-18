--
-- The Kong entry point handler
--

local access = require "kong.plugins.phantom-token.access"

local PhantomToken = {
    PRIORITY = 1000,
    VERSION = "2.0.0",
}

function PhantomToken:access(conf)
    access.run(conf)
end

return PhantomToken
