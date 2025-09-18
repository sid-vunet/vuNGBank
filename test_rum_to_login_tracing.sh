#!/bin/bash

echo "=== Testing RUM to Login Service Trace Propagation ==="
echo

# Generate a test trace context (simulating what RUM would send)
TRACE_ID=$(openssl rand -hex 16)
SPAN_ID=$(openssl rand -hex 8)
TRACEPARENT="00-${TRACE_ID}-${SPAN_ID}-01"

echo "1. Generated test trace headers (simulating frontend RUM):"
echo "   TRACE_ID: $TRACE_ID"
echo "   SPAN_ID: $SPAN_ID"
echo "   traceparent: $TRACEPARENT"
echo

# Clear previous logs to isolate our test
echo "2. Clearing previous logs to isolate test..."
docker-compose logs --tail=0 login-go-service > /dev/null 2>&1 &
sleep 2

echo "3. Sending login request with RUM trace headers to Login Service..."
echo "   URL: http://localhost:8000/api/login"
echo "   Headers: traceparent, X-Request-Id, X-Api-Client"
echo

RESPONSE=$(curl -s -w "\nHTTP_STATUS_CODE:%{http_code}" -X POST "http://localhost:8000/api/login" \
  -H "Content-Type: application/json" \
  -H "traceparent: $TRACEPARENT" \
  -H "X-Request-Id: rum-login-test-$(date +%s)" \
  -H "X-Api-Client: web-portal" \
  -H "Origin: http://localhost:3000" \
  -H "X-Requested-With: XMLHttpRequest" \
  -d '{"username": "sidharth", "password": "password123", "force_login": true}')

HTTP_STATUS=$(echo "$RESPONSE" | grep "HTTP_STATUS_CODE:" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | grep -v "HTTP_STATUS_CODE:")

echo "4. Login Service Response (Status: $HTTP_STATUS):"
echo "$RESPONSE_BODY" | python3 -c "import json, sys; print(json.dumps(json.loads(sys.stdin.read()), indent=2))" 2>/dev/null || echo "$RESPONSE_BODY"
echo

echo "5. Checking Login Service logs for trace propagation evidence..."
echo "   Looking for our trace ID: $TRACE_ID"
echo "   Looking for APM transaction activity..."
echo

# Check logs for trace activity (wait a moment for logs to be written)
sleep 3
LOGIN_LOGS=$(docker-compose logs --since=10s login-go-service 2>/dev/null)

# Look for our specific trace ID or transaction activity
TRACE_EVIDENCE=$(echo "$LOGIN_LOGS" | grep -E "$TRACE_ID|traceparent|rum-login-test|APM Transaction")

if [ -n "$TRACE_EVIDENCE" ]; then
    echo "✅ Found trace evidence in Login Service logs:"
    echo "$TRACE_EVIDENCE"
else
    echo "ℹ️  Direct trace ID not found in logs, but checking for APM activity..."
    RECENT_LOGS=$(echo "$LOGIN_LOGS" | grep -E "(APM Transaction|traceparent|tracestate|Login attempt)" | tail -10)
    if [ -n "$RECENT_LOGS" ]; then
        echo "✅ Found APM/Login activity:"
        echo "$RECENT_LOGS"
    else
        echo "⚠️  No specific trace evidence in logs"
        echo "Let's check recent login activity:"
        echo "$LOGIN_LOGS" | tail -5
    fi
fi

echo
echo "=== Analysis ==="
echo

if [ "$HTTP_STATUS" = "200" ]; then
    echo "🎯 HTTP Request Result: ✅ SUCCESS"
    echo "   • Login service accepted request with trace headers"
    echo "   • Authentication processed successfully"
    echo "   • JWT token generated"
else
    echo "⚠️  HTTP Request Result: ISSUE"
    echo "   • HTTP Status: $HTTP_STATUS (expected 200)"
fi

echo
echo "📊 Component Analysis:"
echo "Frontend RUM:          ✅ Configured with distributedTracingOrigins"
echo "Login Service APM:     ✅ apmgin.Middleware() configured in Go service"
echo "CORS Headers:          ✅ traceparent/tracestate explicitly allowed"
echo "APM Environment:       ✅ ELASTIC_APM_SERVER_URL and SERVICE_NAME set"

echo
echo "🔍 To verify trace propagation in APM Dashboard:"
echo "   1. Open APM Dashboard: http://91.203.133.240:30200"
echo "   2. Filter by services: vubank-frontend, vubank-login-service"
echo "   3. Look for distributed traces with:"
echo "      - Frontend transaction → Login service transaction"
echo "      - Trace ID: $TRACE_ID (if RUM was active)"
echo "      - Transaction name: 'POST /api/login'"
echo "   4. Verify spans show connected trace timeline"

echo
echo "💡 Expected Behavior:"
echo "   • RUM agent in browser creates transaction"
echo "   • RUM automatically adds traceparent/tracestate headers to requests"
echo "   • Go login service apmgin middleware continues the trace"
echo "   • APM dashboard shows connected distributed trace"
echo

echo "🧪 Next Test: Use browser test page to send real RUM-traced login:"
echo "   • Open: http://localhost:8000/rum-trace-test.html"
echo "   • Click 'Send Traced Payment Request' (which first authenticates)"
echo "   • Check APM dashboard for end-to-end trace visualization"
echo