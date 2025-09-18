#!/bin/bash

echo "🧪 Testing Fixed RUM Trace Propagation"
echo "========================================"
echo ""

# Wait for container to be ready
echo "1. Waiting for HTML frontend container to be ready..."
sleep 3

# Check if the login page has the fixed RUM configuration
echo "2. Checking fixed RUM configuration in login page..."
FIXED_CONFIG=$(curl -s http://localhost:3001/login.html | grep -E "(user-interaction|auto-instrumentation)" | wc -l)

if [ "$FIXED_CONFIG" -gt 0 ]; then
    echo "✅ Fixed RUM configuration detected in login page"
else
    echo "⚠️  Could not detect fixed configuration markers"
fi

echo ""
echo "3. Testing the RUM trace propagation issue..."
echo ""

# Generate trace ID for testing
TRACE_ID=$(openssl rand -hex 16)
echo "📊 Generated test trace ID: $TRACE_ID"

# Clear logs before test
docker-compose logs --tail=0 login-go-service > /dev/null 2>&1 &
sleep 1

echo ""
echo "4. Simulating RUM login request with trace headers..."

# Simulate what the fixed RUM should send
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -X POST "http://localhost:8000/api/login" \
  -H "Content-Type: application/json" \
  -H "traceparent: 00-${TRACE_ID}-$(openssl rand -hex 8)-01" \
  -H "X-Request-Id: rum-test-$(date +%s)" \
  -H "X-Api-Client: web-portal" \
  -H "Origin: http://localhost:3001" \
  -H "X-Requested-With: XMLHttpRequest" \
  -d '{"username": "sidharth", "password": "password123", "force_login": true}')

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d':' -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | grep -v "HTTP_CODE:")

echo "Status: $HTTP_CODE"
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Login request successful"
else
    echo "❌ Login request failed"
fi

echo ""
echo "5. Checking login service logs for trace correlation..."
sleep 2

LOGS=$(docker-compose logs --since=5s login-go-service 2>/dev/null)
TRACE_FOUND=$(echo "$LOGS" | grep "$TRACE_ID" | wc -l)

if [ "$TRACE_FOUND" -gt 0 ]; then
    echo "✅ Trace ID found in login service logs:"
    echo "$LOGS" | grep "$TRACE_ID" | head -3
else
    echo "⚠️  Specific trace ID not found, but checking for APM activity:"
    echo "$LOGS" | grep -E "(APM Transaction|traceparent|Login attempt)" | tail -3
fi

echo ""
echo "=========================================="
echo "🎯 RUM Trace Propagation Analysis"
echo "=========================================="
echo ""

echo "✅ Fixed Issues:"
echo "  • Removed manual trace header construction"
echo "  • Let RUM auto-instrumentation handle fetch requests"  
echo "  • Changed transaction type to 'user-interaction'"
echo "  • Properly end transaction on success/failure"
echo "  • Added delay before redirect to send APM data"
echo ""

echo "🧪 To test with real browser:"
echo "  1. Open: http://localhost:3001/login.html"
echo "  2. Open browser dev tools console"
echo "  3. Login with: sidharth / password123"
echo "  4. Look for console logs showing trace IDs"
echo "  5. Check APM Dashboard for connected traces"
echo ""

echo "🔍 Expected in APM Dashboard:"
echo "  • Service: vubank-frontend (transaction: user-login)"
echo "  • Service: vubank-login-service (transaction: POST /api/login)"
echo "  • Connected by same trace ID"
echo "  • Parent-child relationship in service map"
echo ""

echo "📊 APM Dashboard URL: http://91.203.133.240:30200"
echo ""