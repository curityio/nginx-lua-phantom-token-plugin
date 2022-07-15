# Kong Phantom Token Plugin

[![Quality](https://img.shields.io/badge/quality-experiment-red)](https://curity.io/resources/code-examples/status/)
[![Availability](https://img.shields.io/badge/availability-source-blue)](https://curity.io/resources/code-examples/status/)

A plugin to demonstrate how to implement the [Phantom Token Pattern](https://curity.io/resources/learn/phantom-token-pattern/) via LUA.\
This enables a secure API solution when integrating with the Kong API Gateway.

## Plugin Installation

If you are using luarocks, execute the following command to install the plugin:

```bash
luarocks install kong-phantom-token
```

Or deploy the .lua files into Kong's plugin directory, eg `/usr/local/share/lua/5.1/kong/plugins/phantom-token`

## Plugin Configuration

For each API route, configure the plugin using the following configuration.\
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
      introspection_endpoint: $INTROSPECTION_ENDPOINT
      client_id: api-gateway-client
      client_secret: Password1
      token_cache_seconds: 900
      trusted_web_origins:
      - http://$WEB_DOMAIN
```

### Configuration Parameters

| Parameter | Required? | Details |
| --------- | --------- | ------- |
| introspection_endpoint | Yes | The path to the Curity Identity Server's introspection endpoint |
| client_id | Yes | The ID of the introspection client configured in the Curity Identity Server |
| client_secret | Yes | The secret of the introspection client configured in the Curity Identity Server |
| scope | No | One or more scopes can be required for the location, such as `read write` |
| token_prefix | No | Only tokens starting with the given prefix will trigger introspection |
| trusted_web_origins | No | For browser clients, trusted origins can be configured, so that plugin error responses are readable by Javascript code running in browsers |
| verify_ssl | No | An override that can be set to `false` if using untrusted server certificates in the Curity Identity Server. Alternatively you can specify trusted CA certificates via the `lua_ssl_trusted_certificate` directive. See [lua_resty_http](https://github.com/ledgetech/lua-resty-http#request_uri) for further details. |

## Documentation

This repository is documented in the [Kong Open Source API Gateway Integration](https://curity.io/resources/learn/integration-kong-open-source/) article on the Curity Web Site.

## More Information

Please visit [curity.io](https://curity.io/) for more information about the Curity Identity Server.
