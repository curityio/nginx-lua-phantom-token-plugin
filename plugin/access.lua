--
-- A Lua module to handle swapping opaque access tokens for JWTs
--

local _M = {}
local http = require "resty.http"
local jwt = require 'resty.jwt'

--
-- Get values into an array that can be iterated multiple times
--
local function iterator_to_array(iterator)
    
    local i = 1;
    local array = {};

    for item in iterator do
      array[i] = item;
      i = i + 1
    end

    return array
end

--
-- A utility for finding an item in an array
--
local function array_has_value(arr, val)

    for _, item in ipairs(arr) do
        if val == item then
            return true
        end
    end

    return false
end

--
-- Verify configuration and set defaults that are the same for all requests
--
local function initialize_configuration(config)

    if config                          == nil or
       config.introspection_endpoint   == nil or
       config.client_id                == nil or
       config.client_secret            == nil then
         ngx.log(ngx.WARN, 'The phantom token configuration is invalid and must be corrected')
         return false
    end

    if config.token_cache_seconds == nil or config.token_cache_seconds <= 0 then
        config.token_cache_seconds = 300
    end
    if config.scope == nil then
        config.scope = ''
    end
    if config.verify_ssl == nil then
        config.verify_ssl = true
    end

    return true
end

--
-- Return errors due to invalid tokens or introspection technical problems
--
local function error_response(status, code, message)

    local method = ngx.req.get_method():upper()
    if method ~= 'HEAD' then
    
        ngx.status = status
        ngx.header['content-type'] = 'application/json'
        if status == 401 then
            ngx.header['WWW-Authenticate'] = 'Bearer'
        end
        
        local jsonData = '{"code":"' .. code .. '","message":"' .. message .. '"}'
        ngx.say(jsonData)
    end
    
    ngx.exit(status)
end

--
-- Return a generic message for all three of these error categories
--
local function unauthorized_error_response()
    error_response(ngx.HTTP_UNAUTHORIZED, 'unauthorized', 'Missing, invalid or expired access token')
end

local function server_error_response(config)
    error_response(ngx.HTTP_INTERNAL_SERVER_ERROR, 'server_error', 'Problem encountered processing the request')
end

--
-- Introspect the access token
--
local function introspect_access_token(access_token, config)

    local httpc = http:new()
    local clientCredential = ngx.escape_uri(config.client_id) .. ':' .. ngx.escape_uri(config.client_secret)
    local authorizationHeader = 'Basic ' .. ngx.encode_base64(clientCredential)
    local result, error = httpc:request_uri(config.introspection_endpoint, {
        method = 'POST',
        body = 'token=' .. access_token,
        headers = { 
            ['authorization'] = authorizationHeader,
            ['content-type'] = 'application/x-www-form-urlencoded',
            ['accept'] = 'application/jwt'
        },
        ssl_verify = config.verify_ssl
    })
    
    if error then
        local connectionMessage = 'A technical problem occurred during access token introspection: '
        ngx.log(ngx.WARN, connectionMessage .. error)
        return { status = 500 }
    end

    if not result then
        return { status = 500 }
    end

    if result.status ~= 200 then
        return { status = result.status }
    end

    -- Get the time to cache from the cache-control header's max-age value
    local expiry = 0
    if result.headers then
        local cacheHeader = result.headers['cache-control']
        if cacheHeader then
            local _, _, expiryMatch = string.find(cacheHeader, "max.-age=(%d+)")
            if expiryMatch then
                expiry = tonumber(expiryMatch)
            end
        end
    end

    return { status = result.status, jwt = result.body, expiry = expiry }
end

--
-- Optionally check scopes configured for a location
--
local function verify_scope(jwt_text, required_scope)
    
    if required_scope == nil then
        return true
    end

    local data = jwt:load_jwt(jwt_text, nil)
    if not data.valid then
        local details = 'Unable to parse JWT access token'
        if data.reason then
            details = details .. ': ' .. data.reason
        end
        ngx.log(ngx.WARN, details)
        return false
    end

    if not data.payload.scope then
        return false
    end

    local required_scope_parts = string.gmatch(required_scope, "%S+")
    local actual_scope_parts   = iterator_to_array(string.gmatch(data.payload.scope, "%S+"))

    for required_value in required_scope_parts do
        if not array_has_value(actual_scope_parts, required_value) then
            ngx.log(ngx.WARN, 'The required scope ' .. required_value .. ' was not found in the received access token')
            return false
        end
    end

    return true
end

--
-- Get the token from the cache or introspect it
--
local function verify_access_token(access_token, config)

    local result = { status = 401 }

    -- See if there is an introspection result in the cache
    local dict = ngx.shared['phantom-token']
    local existing_jwt = dict:get(access_token)
    if existing_jwt then

        -- Return cached introspection results for the same token
        result = { status = 200, jwt = existing_jwt }
    
    else

        -- Otherwise introspect the opaque access token
        result = introspect_access_token(access_token, config)
        if result.status == 200 then

            local time_to_live = config.token_cache_seconds
            if result.expiry > 0 and result.expiry < config.token_cache_seconds then
                time_to_live = result.expiry
            end

            -- Cache the result so that introspection is efficient under load
            -- The opaque access token is already a unique string similar to a GUID so use it as a cache key
            -- The cache is atomic and thread safe so is safe to use across concurrent requests
            -- The expiry value is a number of seconds from the current time
            -- https://github.com/openresty/lua-nginx-module#ngxshareddictset
            dict:set(access_token, result.jwt, time_to_live)
        end
    end

    -- If configured, verify the scope on every request in a zero-trust manner
    if result.status == 200 then
        if not verify_scope(result.jwt, config.scope) then
            result = { status = 403 }
        end
    end

    return result
end

--
-- The public entry point to introspect the token then forward the JWT to the API
--
function _M.run(config)

    -- Start by validating configuration
    if initialize_configuration(config) == false then 
        server_error_response(config)
        return
    end

    if ngx.req.get_method() == 'OPTIONS' then
        return
    end

    local auth_header = ngx.req.get_headers()['Authorization']
    if auth_header and string.len(auth_header) > 7 and string.lower(string.sub(auth_header, 1, 7)) == 'bearer ' then

        local access_token_untrimmed = string.sub(auth_header, 8)
        local access_token = string.gsub(access_token_untrimmed, "%s+", "")
        local result = verify_access_token(access_token, config)
    
        if result.status == 500 then
            error_response(ngx.HTTP_INTERNAL_SERVER_ERROR, 'server_error', 'Problem encountered authorizing the HTTP request')
        end

        if result.status == 403 then
            error_response(ngx.HTTP_FORBIDDEN, 'forbidden', 'The token does not contain the required scope')
        end

        if result.status ~= 200 then
            ngx.log(ngx.WARN, 'Received a ' .. result.status .. ' introspection response due to the access token being invalid or expired')
            unauthorized_error_response()
        end

        ngx.req.set_header('Authorization', 'Bearer ' .. result.jwt)
    else

        ngx.log(ngx.WARN, 'No valid access token was found in the HTTP Authorization header')
        unauthorized_error_response()
    end
end

return _M
