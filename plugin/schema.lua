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
                { token_cache_seconds = { type = "number", required = false } },
                { scope = { type = "string", required = false } },
                { verify_ssl = { type = "boolean", required = false } },
                { scheme = { type = "string", required = false, one_of = { "Bearer", "DPoP" } } }
            }
        }}
    }
}
