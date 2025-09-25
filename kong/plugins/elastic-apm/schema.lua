local typedefs = require "kong.db.schema.typedefs"

return {
  name = "elastic-apm",
  fields = {
    { consumer = typedefs.no_consumer },
    { protocols = typedefs.protocols_http },
    { config = {
        type = "record",
        fields = {
          { apm_server_url = {
              type = "string",
              required = true,
              default = "http://91.203.133.240:30200",
              description = "URL of the Elastic APM Server"
          }},
          { service_name = {
              type = "string",
              required = true,
              default = "kong-gateway",
              description = "Service name for APM identification"
          }},
          { service_version = {
              type = "string",
              required = true,
              default = "1.0.0",
              description = "Service version for APM"
          }},
          { environment = {
              type = "string",
              required = true,
              default = "production",
              description = "Environment name (production, staging, development)"
          }},
          { secret_token = {
              type = "string",
              required = false,
              description = "Secret token for APM server authentication"
          }},
          { capture_body = {
              type = "boolean",
              required = true,
              default = true,
              description = "Whether to capture request/response bodies"
          }},
          { capture_headers = {
              type = "boolean",
              required = true,
              default = true,
              description = "Whether to capture request/response headers"
          }},
          { transaction_sample_rate = {
              type = "number",
              required = true,
              default = 1.0,
              between = { 0, 1 },
              description = "Sampling rate for transactions (0.0 to 1.0)"
          }},
          { timeout = {
              type = "integer",
              required = true,
              default = 10000,
              description = "Timeout for APM server requests in milliseconds"
          }},
          { keepalive = {
              type = "integer",
              required = true,
              default = 60000,
              description = "Keepalive timeout for APM server connections"
          }},
          { capture_request_body_size_limit = {
              type = "integer",
              required = true,
              default = 1048576, -- 1MB
              description = "Maximum size of request body to capture (bytes)"
          }},
          { capture_response_body_size_limit = {
              type = "integer",
              required = true,
              default = 1048576, -- 1MB
              description = "Maximum size of response body to capture (bytes)"
          }},
          { excluded_paths = {
              type = "array",
              elements = { type = "string" },
              default = { "/health", "/ping", "/status" },
              description = "Paths to exclude from APM monitoring"
          }},
          { include_consumer_info = {
              type = "boolean",
              required = true,
              default = true,
              description = "Whether to include consumer information in APM data"
          }},
          { custom_tags = {
              type = "map",
              keys = { type = "string" },
              values = { type = "string" },
              default = {},
              description = "Custom tags to add to all transactions"
          }},
        },
      },
    },
  },
  entity_checks = {
    { mutually_exclusive = {
        "config.capture_body",
        "config.capture_request_body_size_limit"
    }},
  },
}