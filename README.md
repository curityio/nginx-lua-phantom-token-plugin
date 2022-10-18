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

For each API route, configure the plugin using configuration similar to the following.\
Also add the plugin to the `KONG_PLUGINS` environment variable, by setting it to `bundled,phantom-token`.

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

The plugin can be configured on a per-route basis and use Kong or NGINX's built-in support for routing.\
Advanced options such as routing based on a combination of path and header are therefore supported.\
The following shows an example of bypassing the plugin for API requests with a particular token pattern:

```nginx
http {
    map $http_authorization $loc {
      ~^bearer\s*abc_   loc_bypass;
      default           loc_phantom_token;
    }
    server {
        listen 80;
        location ~ ^/api {
          try_files $uri @$loc;
        }
        location @loc_bypass {
            proxy_pass https://api-internal.example.com:3000;
        }
        location @loc_phantom_token {
            
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
    }
}
```

The equivalent configuration for Kong would be done like this:

```yaml
- name: myapi
  url: https://api-internal.example.com:3000
  routes:
  - name: bypass
    paths:
    - /api
    headers:
      authorization: ["~*bearer\\s*abc_"]

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

## Documentation

See the [OpenResty Integration](https://curity.io/resources/learn/integration-openresty/) article on the Curity Web Site.

## More Information

Please visit [curity.io](https://curity.io/) for more information about the Curity Identity Server.
