return {
    name = "phantom-token",
    fields = {{
        config = {
            type = "record",
            fields = {
                { introspection_endpoint = { type = "string", required = true } },
                { client_id = { type = "string", required = true } },
                { client_secret = { type = "string", required = true } },
                { token_cache_seconds = { type = "number", required = true, default = 0 } },
                { scope = { type = "string", required = false } },
                { verify_ssl = { type = "boolean", required = true, default = true } },
                { trusted_web_origins = { type = "array", required = false, default = {}, elements = { type = "string" } } },
            }
        }}
    }
}