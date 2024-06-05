When using the Kong API gateway you must now provide the following environment variable (see below):

```text
KONG_NGINX_HTTP_LUA_SHARED_DICT: 'phantom-token 10m'
```

The `trusted_web_origins` configuration directive is no longer used.\
For OpenResty, the `time_to_live_seconds` setting has been renamed to `token_cache_seconds`.