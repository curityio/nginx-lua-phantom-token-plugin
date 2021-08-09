local _M = { conf = {} }
local http = require "resty.http"
local pl_stringx = require "pl.stringx"
local jwt_parser = require "kong.plugins.jwt.jwt_parser"

local function array_has_value(arr, val)
    for index, value in ipairs(arr) do
        if value == val then
            return true
        end
    end

    return false
end

--
-- Return errors due to invalid tokens or introspection technical problems
--
local function error_response(status, code, message, config)

    local jsonData = '{"code":"' .. code .. '", "message":"' .. message .. '"}'
    ngx.status = status
    ngx.header['content-type'] = 'application/json'

    if config.trusted_web_origins then

        local origin = ngx.req.get_headers()["origin"]
        if origin and array_has_value(config.trusted_web_origins, origin) then
            ngx.header['Access-Control-Allow-Origin'] = origin
            ngx.header['Access-Control-Allow-Credentials'] = 'true'
        end
    end
    
    ngx.say(jsonData)
    ngx.exit(status)
end

--
-- Return a generic message for all three of these error categories
--
local function invalid_token_error_response(config)
    error_response(ngx.HTTP_UNAUTHORIZED, "unauthorized", "Missing, invalid or expired access token", config)
end

--
-- Do the work of calling the introspection endpoint
--
local function introspect_access_token(access_token, config)

    local httpc = http:new()
    local introspectCredentials = ngx.encode_base64(config.client_id .. ":" .. config.client_secret)
    local res, err = httpc:request_uri(config.introspection_endpoint, {
        method = "POST",
        body = "token=" .. access_token,
        headers = { 
            ["authorization"] = "Basic " .. introspectCredentials,
            ["content-type"] = "application/x-www-form-urlencoded",
            ["accept"] = "application/jwt"
        },
        ssl_verify = config.verify_ssl
    })

    if err then
        local connectionMessage = "A connection problem occurred during access token introspection"
        ngx.log(ngx.WARN, connectionMessage .. err)
        return { status = 0 }
    end

    if not res then
        return { status = 0 }
    end

    if res.status ~= 200 then
        return { status = res.status }
    end

    if res.status == 200 then
        ngx.log(ngx.INFO, "The introspection request was successful")
    end

    return { status = res.status, body = res.body }
end

--
-- Check for a required scope if configured
--
local function verify_scope(jwt_text, required_scope)
    
    if required_scope == nil then
        return true
    end

    local data, err = jwt_parser:new(jwt_text)
    if err then
        ngx.log(ngx.WARN, "Unable to parse JWT access token: " .. err)
        return false
    end

    local scope_values = pl_stringx.split(data.claims.scope, " ")
    for id, scope in ipairs(scope_values) do
        if scope == required_scope then
            return true
        end
    end

    return false
end

--
-- Get the access token from the cache or introspect the token if not found
-- We use the access_token value as the cache key
-- Note also that we pass two arguments to the introspect_access_token callback
--
local function verify_access_token(access_token, config)
    
    local res, err = kong.cache:get(
        access_token,
        { ttl = config.token_cache_seconds },
        introspect_access_token,
        access_token,
        config)

    if err then
        local cacheMessage = "A technical problem occurred during cache access"
        ngx.log(ngx.WARN, cacheMessage .. err)
        error_response(ngx.HTTP_INTERNAL_SERVER_ERROR, "cache_error", cacheMessage, config)
    end 

    if res.status ~= 200 then
        kong.cache:invalidate(access_token)
    end

    if res.status == 204 then
        ngx.log(ngx.WARN, "Received a " .. res.status .. " introspection response due to the access token being invalid or expired")
        invalid_token_error_response(config)
    end

    if res.status ~= 200 then

        local introspectionMessage = "A technical problem occurred during access token introspection"
        local logMessage = introspectionMessage .. ", Status: " .. res.status
        if res.body then
            logMessage = logMessage .. ", Body: " .. res.body
        end
        ngx.log(ngx.WARN, logMessage)

        error_response(ngx.HTTP_INTERNAL_SERVER_ERROR, "introspection_error", introspectionMessage, config)
    end

    return res
end

--
-- The public entry point to introspect the token then forward the JWT to the API
--
function _M.run(config)

    if ngx.req.get_method() == "OPTIONS" then
        return
    end

    local access_token = ngx.req.get_headers()["Authorization"]
    if access_token then
        access_token = pl_stringx.replace(access_token, "Bearer ", "", 1)
    end

    if not access_token then
        ngx.log(ngx.WARN, "No access token was found in the Authorization bearer header")
        invalid_token_error_response(config)
    end

    local res = verify_access_token(access_token, config)
    local jwt = res.body

    if not verify_scope(jwt, config.scope) then
        error_response(ngx.HTTP_FORBIDDEN, "forbidden", "The token does not contain the required scope: " .. config.scope, config)
    end

    ngx.log(ngx.INFO, "The request was successfully authorized by the gateway")
    ngx.req.set_header("Authorization", "Bearer " .. jwt)
end

return _M
