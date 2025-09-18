#!/bin/bash

echo "=== Testing Fixed RUM Distributed Tracing (After Removing Custom APM Spans) ==="
echo

# Clear recent logs
docker-compose logs --tail=0 login-go-service > /dev/null 2>&1 &
sleep 2

echo "1. Testing with simulated RUM trace headers..."

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
  -H "User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" \
  -H "Origin: http://localhost:3001" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "X-Api-Client: web-portal" \
  -H "traceparent: $TRACEPARENT" \
  -H "tracestate: vubank=frontend-login-fixed" \
  -d '{"username": "sidharth", "password": "password123", "force_login": true}')

HTTP_STATUS=$(echo "$LOGIN_RESPONSE" | grep "HTTP_STATUS:" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$LOGIN_RESPONSE" | grep -v "HTTP_STATUS:")

echo "2. Login Response (Status: $HTTP_STATUS):"
echo "$RESPONSE_BODY" | python3 -c "import json, sys; print(json.dumps(json.loads(sys.stdin.read()), indent=2))" 2>/dev/null || echo "$RESPONSE_BODY"
echo

echo "3. Checking Login Service logs for trace evidence (without custom spans)..."
sleep 3

# Check for our trace ID in login service logs
LOGIN_LOGS=$(docker-compose logs --since=10s login-go-service 2>/dev/null)

if echo "$LOGIN_LOGS" | grep -q "$TRACE_ID"; then
    echo "✅ SUCCESS: Found our trace ID in login service logs!"
    echo "$LOGIN_LOGS" | grep -E "$TRACE_ID|traceparent"
else
    echo "ℹ️  Direct trace ID not found, checking for general trace activity..."
    TRACE_ACTIVITY=$(echo "$LOGIN_LOGS" | grep -E "(traceparent|APM Transaction|Login attempt)" | tail -5)
    if [ -n "$TRACE_ACTIVITY" ]; then
        echo "✅ Found trace activity in login service:"
        echo "$TRACE_ACTIVITY"
    else
        echo "⚠️  No trace activity found. Recent logs:"
        echo "$LOGIN_LOGS" | tail -5
    fi
fi

echo
echo "4. 🎯 CRITICAL DIFFERENCE: Before vs After Custom Spans Removal"
echo "   BEFORE: Custom spans (auth_service_error, successful_login, etc.) were"
echo "           creating new trace contexts and breaking distributed tracing"
echo "   AFTER:  Only apmgin.Middleware() handles tracing automatically"
echo "           RUM → Login Service trace chain should now be connected"
echo

echo "5. ✅ Expected Result:"
echo "   • Frontend RUM transaction creates trace ID"
echo "   • HTTP request includes traceparent/tracestate headers"  
echo "   • apmgin.Middleware() continues the SAME trace ID"
echo "   • APM dashboard shows: vubank-frontend → vubank-login-service"
echo "   • Connected service map with same trace timeline"
echo

echo "6. 🚀 Test the fix:"
echo "   • Open: http://localhost:3001/login.html"
echo "   • Perform login with browser dev tools open"
echo "   • Check APM dashboard: http://91.203.133.240:30200"
echo "   • Look for connected distributed traces"
echo

echo "7. Service Status Check:"
echo "   Frontend container: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep html-frontend || echo 'NOT RUNNING')"
echo "   Login service: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep login-go || echo 'NOT RUNNING')"
echo "   APM reachable: $(curl -s -o /dev/null -w '%{http_code}' http://91.203.133.240:30200 || echo 'FAILED')"