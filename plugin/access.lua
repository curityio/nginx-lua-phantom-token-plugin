local _M = { conf = {} }
local http = require "resty.http"
local pl_stringx = require "pl.stringx"
local jwt_parser = require "kong.plugins.jwt.jwt_parser"

--
-- The plugin entry point to introspect the token then forward the JWT to the API
--
function _M.run(conf)

    _M.conf = conf
    if ngx.req.get_method() == "OPTIONS" then
        return
    end

    local access_token = ngx.req.get_headers()["Authorization"]
    if access_token then
        access_token = pl_stringx.replace(access_token, "Bearer ", "", 1)
    end

    if not access_token then
        ngx.log(ngx.WARN, "No access token was found in the Authorization bearer header")
        _M.invalid_token_error_response()
    end

    local res = _M.introspect_access_token(access_token)
    local jwt = res.body

    if not _M.is_scope_authorized(jwt) then
        _M.error_response(ngx.HTTP_FORBIDDEN, "forbidden", "The token does not contain the scope required for this API operation")
    end

    ngx.log(ngx.INFO, "The request was successfully authorized by the gateway")
    ngx.req.set_header("Authorization", "Bearer " .. jwt)
end

--
-- Get the access token from the cache or introspect it is not found
--
function _M.introspect_access_token(access_token)
    
    local cache_id = "at:" .. access_token
    local res, err = kong.cache:get(
        cache_id,
        { ttl = _M.conf.token_cache_seconds },
        _M.introspect_access_token_req,
        access_token)

    if err then
        local cacheMessage = "A technical problem occurred during cache access"
        ngx.log(ngx.WARN, cacheMessage .. err)
        _M.error_response(ngx.HTTP_INTERNAL_SERVER_ERROR, "cache_error", cacheMessage)
    end 

    if res.status ~= 200 then
        kong.cache:invalidate(cache_id)
    end

    if res.status == 204 then
        ngx.log(ngx.WARN, "The access token received a " .. res.status .. " introspection response and is expired")
        _M.invalid_token_error_response()
    end

    if res.status ~= 200 then

        local introspectionMessage = "A technical problem occurred during access token introspection"
        local logMessage = introspectionMessage .. ", Status: " .. res.status
        if res.body then
            logMessage = logMessage .. ", Body: " .. res.body
        end
        ngx.log(ngx.WARN, logMessage)

        _M.error_response(ngx.HTTP_INTERNAL_SERVER_ERROR, "introspection_error", introspectionMessage)
    end

    return res
end

--
-- Do the work of calling the introspection endpoint
--
function _M.introspect_access_token_req(access_token)

    local httpc = http:new()

    local introspectCredentials = ngx.encode_base64(_M.conf.client_id .. ":" .. _M.conf.client_secret)
    local res, err = httpc:request_uri(_M.conf.introspection_endpoint, {
        method = "POST",
        body = "token=" .. access_token,
        headers = { 
            ["authorization"] = "Basic " .. introspectCredentials,
            ["content-type"] = "application/x-www-form-urlencoded",
            ["accept"] = "application/jwt"
        }
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
function _M.is_scope_authorized(jwt_text)
    
    if _M.conf.scope == nil then
        return true
    end

    local data, err = jwt_parser:new(jwt_text)
    if err then
        ngx.log(ngx.WARN, "Unable to parse JWT access token: " .. err)
        return false
    end

    local scope = data.claims.scope
    local needed_scope = pl_stringx.strip(_M.conf.scope)
    if string.len(needed_scope) == 0 then
        return true
    end

    scope = pl_stringx.strip(scope)
    if string.find(scope, '*', 1, true) or string.find(scope, needed_scope, 1, true) then
        return true
    end

    return false
end

--
-- Return a generic message for all three of these error categories
--
function _M.invalid_token_error_response()
    _M.error_response(ngx.HTTP_UNAUTHORIZED, "unauthorized", "Missing, invalid or expired access token")
end

--
-- Return errors due to invalid tokens or introspection technical problems
--
function _M.error_response(status, code, message)

    local jsonData = '{"code":"' .. code .. '", "message":"' .. message .. '"}'
    ngx.status = status
    ngx.header['content-type'] = 'application/json'
    ngx.say(jsonData)
    ngx.exit(status)
end

return _M
