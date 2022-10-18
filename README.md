# Phantom Token Plugin for NGINX LUA Systems

[![Quality](https://img.shields.io/badge/quality-test-yellow)](https://curity.io/resources/code-examples/status/)
[![Availability](https://img.shields.io/badge/availability-binary-blue)](https://curity.io/resources/code-examples/status/)

A LUA plugin used to introspect opaque access tokens and forward JWT access tokens to APIs.

## The Phantom Token Pattern

The [Phantom Token Pattern](https://curity.io/resources/learn/phantom-token-pattern/) is a privacy preserving pattern in API security.\
It ensures that access tokens returned to internet clients are kept confidential while also ensuring simple but secure API code.

![Phantom Token Pattern](images/phantom-token-pattern.png)

## Installation

### Kong API Gateway

If you are using luarocks, execute the following command to install the plugin:

```bash
luarocks install kong-phantom-token
```

Or deploy the .lua files into Kong's plugin directory, eg `/usr/local/share/lua/5.1/kong/plugins/phantom-token`.

### OpenResty

If you are using luarocks, execute the following command to install the plugin:

```bash
luarocks install lua-resty-phantom-token
```

Or deploy the `plugin.lua` file to `resty/phantom-token.lua`, where the resty folder is in the `lua_package_path`.

## Configuration

### Kong API Gateway

For each API route, configure the plugin using configuration similar to the following:

```yaml
- name: myapi
  url: https://api-internal.example.com:3000
  routes:
  - name: myapi-route
    paths:
    - /api
  plugins:
  - name: phantom-token
    config:
      introspection_endpoint: https://login.example.com/oauth/v2/oauth-introspect
      client_id: introspection-client
      client_secret: Password1
      token_cache_seconds: 900
```

When deploying Kong, set environment variables similar to these.\
In particular set the values for `KONG_PLUGINS` and `KONG_NGINX_HTTP_LUA_SHARED_DICT`.

```yaml
environment:
  KONG_DATABASE: 'off'
  KONG_DECLARATIVE_CONFIG: '/usr/local/kong/declarative/kong.yml'
  KONG_PROXY_LISTEN: '0.0.0.0:3000'
  KONG_LOG_LEVEL: 'info'
  KONG_PLUGINS: 'bundled,phantom-token'
  KONG_NGINX_HTTP_LUA_SHARED_DICT: 'phantom-token 10m'
```

### OpenResty

If using OpenResty, then first configure a cache for introspection results.\
The [ngx.share.DICT](https://github.com/openresty/lua-nginx-module#ngxshareddict) is used as a cache, so first use the following NGINX directive:

```nginx
http {
    lua_shared_dict phantom-token 10m;
    server {
        ...
    }
}
```

Then apply the plugin to one or more locations with configuration similar to the following:

```nginx
location ~ ^/api {

    rewrite_by_lua_block {

        local config = {
            introspection_endpoint = 'https://login.example.com/oauth/v2/oauth-introspect',
            client_id = 'introspection-client',
            client_secret = 'Password1',
            token_cache_seconds = 900
        }

        local phantomTokenPlugin = require 'resty.phantom-token'
        phantomTokenPlugin.execute(config)
    }

    proxy_pass https://api-internal.example.com:3000;
}
```

## Configuration Parameters

| Parameter | Required? | Details |
| --------- | --------- | ------- |
| introspection_endpoint | Yes | The path to the Curity Identity Server's introspection endpoint |
| client_id | Yes | The ID of the introspection client configured in the Curity Identity Server |
| client_secret | Yes | The secret of the introspection client configured in the Curity Identity Server |
| token_cache_seconds | No | The maximum time for which each result is cached |
| scope | No | One or more scopes can be required for the location, such as `read write` |
| verify_ssl | No | An override that can be set to `false` if using untrusted server certificates in the Curity Identity Server. Alternatively you can specify trusted CA certificates via the `lua_ssl_trusted_certificate` directive. See [lua_resty_http](https://github.com/ledgetech/lua-resty-http#request_uri) for further details. |

## Advanced Configurations

You can apply the plugin to a subset of the API routes, or use the advanced routing features of the reverse proxy.\
The following Kong configuration is for a use case where a route handles both JWTs and opaque tokens.\
This might enable a microservice developer to forward a JWT an upstream microservice behind a gateway.

```yaml
- name: myapi
  url: https://api-internal.example.com:3000
  routes:
  - name: bypass
    paths:
    - /api
    headers:
      authorization: ["~*bearer\\s*[A-Za-z0-9-_]*\.[A-Za-z0-9-_]*\.[A-Za-z0-9-_]*"]

  - name: phantom-token
    paths:
    - /api
    plugins:
    - name: phantom-token
      config:
        introspection_endpoint: https://login.example.com/oauth/v2/oauth-introspect
        client_id: introspection-client
        client_secret: Password1
        token_cache_seconds: 900
```

The equivalent OpenResty configuration is shown in [these tests](/t/advancedRouting.t).

## Tutorial Documentation

See these tutorials for step by step details on integrating the phantom token plugin:

- [Kong Phantom Token Integration](https://curity.io/resources/learn/integration-kong-open-source/)
- [OpenResty Phantom Token Integration](https://curity.io/resources/learn/integration-openresty/)

## More Information

Please visit [curity.io](https://curity.io/) for more information about the Curity Identity Server.
