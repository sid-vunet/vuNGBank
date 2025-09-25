-- Kong Elastic APM Plugin (Simplified)
-- Basic APM integration without external dependencies

local kong = kong
local ngx = ngx

local plugin = {
  PRIORITY = 1000, -- Set priority to run early
  VERSION = "1.0.0",
}

local SCHEMA = {
  name = "elastic-apm",
  fields = {
    { config = {
        type = "record",
        fields = {
          { apm_server_url = { type = "string", default = "http://91.203.133.240:30200" } },
          { service_name = { type = "string", default = "kong-gateway" } },
          { service_version = { type = "string", default = "1.0.0" } },
          { environment = { type = "string", default = "production" } },
          { capture_body = { type = "boolean", default = false } },
          { capture_headers = { type = "boolean", default = true } },
        },
      },
    },
  },
}

plugin.schema = SCHEMA

-- Simple ID generation
local function generate_id(length)
  length = length or 16
  local chars = "0123456789abcdef"
  local id = ""
  
  -- Seed random with current time
  math.randomseed(ngx.now() * 1000)
  
  for i = 1, length do
    local idx = math.random(1, #chars)
    id = id .. chars:sub(idx, idx)
  end
  
  return id
end

-- Get or create correlation ID
local function get_correlation_id()
  local correlation_id = kong.request.get_header("X-Correlation-ID")
  if not correlation_id then
    correlation_id = "vubank-" .. generate_id(8) .. "-" .. generate_id(4) .. "-" .. generate_id(4) .. "-" .. generate_id(12)
    kong.service.request.set_header("X-Correlation-ID", correlation_id)
  end
  return correlation_id
end

-- Preserve trace context headers
local function preserve_trace_context()
  local traceparent = kong.request.get_header("traceparent")
  local tracestate = kong.request.get_header("tracestate")
  
  -- Forward trace context to upstream services
  if traceparent then
    kong.service.request.set_header("traceparent", traceparent)
  end
  
  if tracestate then
    kong.service.request.set_header("tracestate", tracestate)
  end
  
  return traceparent, tracestate
end

function plugin:access(config)
  -- Start timing
  ngx.ctx.apm_start_time = ngx.now()
  
  -- Get or create correlation ID
  local correlation_id = get_correlation_id()
  ngx.ctx.correlation_id = correlation_id
  
  -- Preserve and forward trace context
  local traceparent, tracestate = preserve_trace_context()
  ngx.ctx.traceparent = traceparent
  
  -- Add request ID header for tracking
  local request_id = "req-" .. generate_id(12)
  kong.service.request.set_header("X-Request-ID", request_id)
  
  -- Log request start
  kong.log.info("[APM_REQUEST] Start: ", correlation_id, " Method: ", kong.request.get_method(), " Path: ", kong.request.get_path())
end

function plugin:log(config)
  -- Log request completion with timing
  local start_time = ngx.ctx.apm_start_time or ngx.now()
  local correlation_id = ngx.ctx.correlation_id or "unknown"
  local duration = (ngx.now() - start_time) * 1000 -- Convert to milliseconds
  
  kong.log.info("[APM_RESPONSE] End: ", correlation_id, " Status: ", kong.response.get_status(), " Duration: ", duration, "ms")
end

return plugin