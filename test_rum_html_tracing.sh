#!/bin/bash

echo "=== Testing RUM Distributed Tracing from HTML Container ==="
echo

# Clear recent logs
docker-compose logs --tail=0 login-go-service > /dev/null 2>&1 &
sleep 1

echo "1. Making a direct login request to verify trace header reception..."

# Use Chrome/browser user agent to simulate real browser request
USER_AGENT="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

# Generate trace context like RUM would
TRACE_ID=$(openssl rand -hex 16)
SPAN_ID=$(openssl rand -hex 8)
TRACEPARENT="00-${TRACE_ID}-${SPAN_ID}-01"

echo "   Simulating RUM trace context:"
echo "   Trace ID: $TRACE_ID"
echo "   traceparent: $TRACEPARENT"
echo

LOGIN_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -X POST "http://localhost:8000/api/login" \
  -H "Content-Type: application/json" \
  -H "User-Agent: $USER_AGENT" \
  -H "Origin: http://localhost:3001" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "X-Api-Client: web-portal" \
  -H "traceparent: $TRACEPARENT" \
  -H "tracestate: vubank=frontend-login" \
  -d '{"username": "sidharth", "password": "password123", "force_login": true}')

HTTP_STATUS=$(echo "$LOGIN_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$LOGIN_RESPONSE" | grep -v "HTTP_STATUS:")

echo "2. Login Response (Status: $HTTP_STATUS):"
echo "$RESPONSE_BODY" | python3 -c "import json, sys; print(json.dumps(json.loads(sys.stdin.read()), indent=2))" 2>/dev/null || echo "$RESPONSE_BODY"
echo

echo "3. Checking Login Service logs for trace evidence..."
sleep 3

# Check for our trace ID in login service logs
LOGIN_LOGS=$(docker-compose logs --since=10s login-go-service 2>/dev/null)

if echo "$LOGIN_LOGS" | grep -q "$TRACE_ID"; then
    echo "✅ SUCCESS: Found our trace ID in login service logs!"
    echo "$LOGIN_LOGS" | grep "$TRACE_ID"
else
    echo "ℹ️  Direct trace ID not found, checking for general trace activity..."
    TRACE_ACTIVITY=$(echo "$LOGIN_LOGS" | grep -E "(traceparent|APM Transaction|tracestate)" | tail -5)
    if [ -n "$TRACE_ACTIVITY" ]; then
        echo "✅ Found trace activity in login service:"
        echo "$TRACE_ACTIVITY"
    else
        echo "⚠️  No trace activity found. Recent logs:"
        echo "$LOGIN_LOGS" | tail -5
    fi
fi

echo
echo "4. Now testing from HTML frontend container..."
echo "   Please open: http://localhost:3001/login.html"
echo "   And perform a login while monitoring the APM dashboard"
echo
echo "5. Expected behavior:"
echo "   • RUM transaction starts on login button click"
echo "   • RUM auto-instruments the fetch() call to localhost:8000"
echo "   • traceparent/tracestate headers added automatically"
echo "   • Login service continues the trace (same trace ID)"
echo "   • APM dashboard shows: vubank-frontend → vubank-login-service"
echo

echo "6. Debugging checklist:"
echo "   ✓ Frontend container running: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep html-frontend || echo 'NOT RUNNING')"
echo "   ✓ Login service running: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep login-go || echo 'NOT RUNNING')"
echo "   ✓ APM server reachable: $(curl -s -o /dev/null -w '%{http_code}' http://91.203.133.240:30200 || echo 'FAILED')"
echo
echo "7. If still not working, the issue might be:"
echo "   • RUM transaction lifecycle (ending too early)"
echo "   • APM server configuration"
echo "   • Browser CORS blocking trace headers"
echo "   • Service naming mismatch in APM"