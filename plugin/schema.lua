return {
    name = "phantom-token",
    fields = {{
        config = {
            type = "record",
            required = true,
            fields = {
                { introspection_endpoint = { type = "string", required = true, match = "^https?://" } },
                { client_id = { type = "string", required = true } },
                { client_secret = { type = "string", required = true } },
                { token_cache_seconds = { type = "number", required = true, default = 300 } },
                { scope = { type = "string", required = false } },
                { verify_ssl = { type = "boolean", required = false, default = true } },
                { scheme = { type = "string", required = false, default = "Bearer", one_of = { "Bearer", "DPoP" } } }
            }
        }}
    }
}
