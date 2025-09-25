local plugin_name = "elastic-apm"
local package_name = "kong-plugin-" .. plugin_name
local package_version = "1.0.0"
local rockspec_revision = "1"

local github_account_name = "vubank"
local github_repo_name = "kong-plugin-elastic-apm"

package = package_name
version = package_version .. "-" .. rockspec_revision

supported_platforms = { "linux", "macosx" }
source = {
  url = "git+https://github.com/" .. github_account_name .. "/" .. github_repo_name .. ".git",
  branch = "main",
}

description = {
  summary = "Kong plugin for Elastic APM integration with comprehensive monitoring",
  detailed = [[
    This Kong plugin integrates with Elastic APM to provide comprehensive monitoring
    and distributed tracing for API gateway traffic. It captures request/response
    data, maintains trace context, and sends telemetry to Elastic APM server.
  ]],
  license = "MIT",
  homepage = "https://github.com/" .. github_account_name .. "/" .. github_repo_name,
}

dependencies = {
  "lua >= 5.1",
  "lua-resty-http",
  "lua-cjson",
  "lua-resty-jit-uuid",
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins." .. plugin_name .. ".handler"] = "kong/plugins/" .. plugin_name .. "/handler.lua",
    ["kong.plugins." .. plugin_name .. ".schema"] = "kong/plugins/" .. plugin_name .. "/schema.lua",
  }
}