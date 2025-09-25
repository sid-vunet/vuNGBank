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

local function get_trace_context()
  local traceparent = kong.request.get_header("traceparent")
  local tracestate = kong.request.get_header("tracestate")
  
  if traceparent then
    -- Parse existing trace context from upstream services
    local trace_id = traceparent:match("00%-([%w]+)%-")
    local parent_id = traceparent:match("00%-[%w]+%-([%w]+)%-")
    return trace_id, parent_id, tracestate
  end
  
  -- Generate new trace context if none exists
  local trace_id = uuid.generate_v4():gsub("-", "")
  local span_id = uuid.generate_v4():gsub("-", ""):sub(1, 16)
  return trace_id, nil, nil, span_id
end

local function capture_request_data()
  local method = kong.request.get_method()
  local url = kong.request.get_forwarded_scheme() .. "://" .. 
              kong.request.get_forwarded_host() .. 
              kong.request.get_forwarded_path()
  local headers = kong.request.get_headers()
  local body = nil
  
  if method ~= "GET" and method ~= "HEAD" then
    body = kong.request.get_raw_body()
  end
  
  return {
    method = method,
    url = url,
    headers = headers,
    body = body,
    remote_addr = kong.client.get_ip(),
    user_agent = headers["user-agent"],
    content_length = headers["content-length"],
  }
end

local function capture_response_data()
  local status = kong.response.get_status()
  local headers = kong.response.get_headers()
  local body = kong.response.get_raw_body()
  
  return {
    status_code = status,
    headers = headers,
    body = body,
    content_length = headers["content-length"],
  }
end

local function create_apm_transaction(config, request_data, response_data, duration, trace_id, parent_id, span_id)
  local transaction_id = span_id or uuid.generate_v4():gsub("-", ""):sub(1, 16)
  
  -- Create transaction metadata
  local metadata = {
    service = {
      name = config.service_name,
      version = config.service_version,
      environment = config.environment,
      agent = {
        name = "kong-elastic-apm-plugin",
        version = plugin.VERSION,
      },
    },
    labels = {
      gateway = "kong",
      route = kong.router.get_route() and kong.router.get_route().name or "unknown",
      service = kong.router.get_service() and kong.router.get_service().name or "unknown",
    },
  }
  
  -- Create transaction data
  local transaction = {
    id = transaction_id,
    trace_id = trace_id,
    parent_id = parent_id,
    name = request_data.method .. " " .. (kong.router.get_route() and kong.router.get_route().name or request_data.url),
    type = "request",
    duration = duration,
    result = tostring(response_data.status_code),
    outcome = response_data.status_code < 400 and "success" or "failure",
    timestamp = os.time() * 1000000, -- Convert to microseconds
    sampled = math.random() <= config.transaction_sample_rate,
    context = {
      request = {
        method = request_data.method,
        url = {
          full = request_data.url,
          pathname = kong.request.get_path(),
          search = kong.request.get_raw_query(),
        },
        headers = config.capture_headers and request_data.headers or {},
        body = config.capture_body and request_data.body or nil,
        socket = {
          remote_address = request_data.remote_addr,
        },
      },
      response = {
        status_code = response_data.status_code,
        headers = config.capture_headers and response_data.headers or {},
        body = config.capture_body and response_data.body or nil,
      },
      user = {
        id = kong.client.get_credential() and kong.client.get_credential().id or nil,
        username = kong.client.get_consumer() and kong.client.get_consumer().username or nil,
      },
      tags = {
        kong_version = kong.version,
        gateway_id = "vubank-gateway",
      },
    },
  }
  
  return {
    metadata = { metadata },
    transaction = { transaction },
  }
end

local function send_to_apm(config, apm_data)
  local httpc = http.new()
  httpc:set_timeout(config.timeout)
  
  -- Prepare NDJSON format for Elastic APM
  local ndjson_lines = {}
  for _, item in ipairs(apm_data.metadata) do
    table.insert(ndjson_lines, '{"metadata":' .. cjson.encode(item) .. '}')
  end
  for _, item in ipairs(apm_data.transaction) do
    table.insert(ndjson_lines, '{"transaction":' .. cjson.encode(item) .. '}')
  end
  
  local body = table.concat(ndjson_lines, '\n') .. '\n'
  
  local headers = {
    ["Content-Type"] = "application/x-ndjson",
    ["User-Agent"] = "kong-elastic-apm-plugin/" .. plugin.VERSION,
  }
  
  if config.secret_token then
    headers["Authorization"] = "Bearer " .. config.secret_token
  end
  
  local res, err = httpc:request_uri(config.apm_server_url .. "/intake/v2/events", {
    method = "POST",
    headers = headers,
    body = body,
    keepalive_timeout = config.keepalive,
    keepalive_pool = 10,
  })
  
  if not res then
    kong.log.err("Failed to send APM data: ", err)
    return false
  end
  
  if res.status ~= 202 then
    kong.log.err("APM server returned status: ", res.status, " body: ", res.body)
    return false
  end
  
  return true
end

function plugin:access(config)
  -- Capture request start time
  kong.ctx.plugin.start_time = kong.request.get_start_time()
  
  -- Get or create trace context
  local trace_id, parent_id, tracestate, span_id = get_trace_context()
  
  -- Store trace context for later use
  kong.ctx.plugin.trace_id = trace_id
  kong.ctx.plugin.parent_id = parent_id
  kong.ctx.plugin.span_id = span_id
  kong.ctx.plugin.tracestate = tracestate
  
  -- Capture request data
  kong.ctx.plugin.request_data = capture_request_data()
  
  -- Set trace headers for downstream services (preserve existing tracing)
  if not kong.request.get_header("traceparent") and trace_id and span_id then
    local traceparent = "00-" .. trace_id .. "-" .. span_id .. "-01"
    kong.service.request.set_header("traceparent", traceparent)
  end
  
  -- Add Kong-specific headers
  kong.service.request.set_header("X-Kong-Request-ID", kong.request.get_header("X-Request-ID"))
  kong.service.request.set_header("X-Kong-Correlation-ID", kong.request.get_header("X-Correlation-ID"))
end

function plugin:body_filter(config)
  -- This runs for each chunk of the response body
  -- We'll capture the full response in the log phase
end

function plugin:log(config)
  -- Calculate duration
  local duration = (kong.request.get_start_time() - kong.ctx.plugin.start_time) * 1000 -- Convert to milliseconds
  
  -- Capture response data
  local response_data = capture_response_data()
  
  -- Create APM transaction
  local apm_data = create_apm_transaction(
    config,
    kong.ctx.plugin.request_data,
    response_data,
    duration,
    kong.ctx.plugin.trace_id,
    kong.ctx.plugin.parent_id,
    kong.ctx.plugin.span_id
  )
  
  -- Send to APM server asynchronously
  kong.timer:at(0, function()
    send_to_apm(config, apm_data)
  end)
end

return plugin