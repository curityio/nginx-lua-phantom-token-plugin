package = "phantom-token"
version = "1.0.0-2"
source = {
  url = "."
}
description = {
  summary = "A Kong custom plugin to implement the phantom token pattern"
}
dependencies = {
  "lua >= 5.1"
}
build = {
  type = "builtin",
  modules = {
    ["kong.plugins.phantom-token.access"] = "access.lua",
    ["kong.plugins.phantom-token.handler"] = "handler.lua",
    ["kong.plugins.phantom-token.schema"] = "schema.lua"
  }
}