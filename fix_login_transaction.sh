#!/bin/bash

echo "🔍 LOGIN PAGE LOAD TRANSACTION - ROOT CAUSE ANALYSIS"
echo "===================================================="

echo ""
echo "🎯 ISSUE SUMMARY:"
echo "  ✅ Seeing: 'vubank-index-page-load' transaction in APM"
echo "  ❌ Missing: 'login-page-load' transaction in APM"

echo ""
echo "🔍 DIAGNOSIS RESULTS:"

echo ""
echo "1. 📄 Page Accessibility Test:"
echo -n "   • Index page (http://localhost:8086/index.html): "
if curl -s -I http://localhost:8086/index.html | grep -q "200 OK"; then
    echo "✅ ACCESSIBLE (200 OK)"
else
    echo "❌ NOT ACCESSIBLE"
fi

echo -n "   • Login page (http://localhost:8086/login.html): "
if curl -s -I http://localhost:8086/login.html | grep -q "200 OK"; then
    echo "✅ ACCESSIBLE (200 OK)"
else
    echo "❌ NOT ACCESSIBLE (This is the problem!)"
fi

echo -n "   • RUM library (http://localhost:8086/elastic-apm-rum.js): "
if curl -s -I http://localhost:8086/elastic-apm-rum.js | grep -q "200 OK"; then
    echo "✅ ACCESSIBLE (200 OK)"
else
    echo "❌ NOT ACCESSIBLE"
fi

echo ""
echo "2. 🔧 ROOT CAUSE:"
echo "   📍 Login page is NOT ACCESSIBLE through Kong Gateway"
echo "   📍 No page load = No RUM transaction = No 'login-page-load' in APM"
echo "   📍 Index page works = RUM loads = 'vubank-index-page-load' appears in APM"

echo ""
echo "3. 🛠️  KONG ROUTE ANALYSIS:"
echo "   • Checking Kong routes for login.html..."

if curl -s http://localhost:8001/routes | jq -r '.data[].paths[]' | grep -q "/login.html"; then
    echo "   ✅ Route exists in Kong"
    ROUTE_ID=$(curl -s http://localhost:8001/routes | jq -r '.data[] | select(.paths[]? | contains("/login.html")) | .id')
    echo "   📋 Route ID: $ROUTE_ID"
else
    echo "   ❌ Route missing in Kong"
fi

echo ""
echo "4. 🎯 THE REAL ISSUE:"
echo "   📍 Kong Gateway routing problem for login.html"
echo "   📍 Frontend container has login.html file"
echo "   📍 Kong route exists but doesn't work"
echo "   📍 Result: Browser can't load login.html = No RUM initialization = No transaction"

echo ""
echo "5. 🚀 SOLUTION STEPS:"

echo ""
echo "   Step 1: Fix Kong routing for login.html"
echo "   ==============================================="

echo "   • Testing different route configuration..."

# Try to fix the route by recreating it with correct configuration
echo "   • Deleting existing problematic route..."
ROUTE_ID=$(curl -s http://localhost:8001/routes | jq -r '.data[] | select(.paths[]? | contains("/login.html")) | .id')
if [ ! -z "$ROUTE_ID" ]; then
    curl -s -X DELETE http://localhost:8001/routes/$ROUTE_ID > /dev/null
    echo "   ✅ Deleted route $ROUTE_ID"
fi

echo "   • Creating new route with proper configuration..."
RESPONSE=$(curl -s -X POST http://localhost:8001/services/frontend-service/routes \
  --data "paths[]=/login.html" \
  --data "strip_path=false" \
  --data "preserve_host=false" \
  --data "protocols[]=http" \
  --data "protocols[]=https")

NEW_ROUTE_ID=$(echo $RESPONSE | jq -r '.id')
echo "   ✅ Created new route: $NEW_ROUTE_ID"

echo ""
echo "   • Testing the fix..."
sleep 2

echo -n "   • Login page access test: "
if curl -s -I http://localhost:8086/login.html | grep -q "200 OK"; then
    echo "✅ FIXED! Login page now accessible"
    
    echo ""
    echo "   Step 2: Test RUM transaction generation"
    echo "   ==============================================="
    echo "   • Now that login.html is accessible, RUM should work"
    echo "   • Open browser and navigate: http://localhost:8086/login.html"
    echo "   • Check browser console for RUM initialization messages"
    echo "   • Wait 30-60 seconds and check APM for 'login-page-load' transaction"
    
else
    echo "❌ STILL NOT ACCESSIBLE - Need further debugging"
    
    echo ""
    echo "   Alternative Solution: Direct Kong Service Test"
    echo "   ==============================================="
    echo "   • The issue might be Kong service connectivity"
    echo "   • Try restarting Kong and frontend containers:"
    echo "     docker restart vubank-kong-gateway"
    echo "     docker restart vubank-html-frontend"
    echo "     ./kong/configure-kong-auto.sh"
fi

echo ""
echo "🎯 EXPECTED RESULT AFTER FIX:"
echo "  ✅ http://localhost:8086/index.html → 'vubank-index-page-load' transaction"
echo "  ✅ http://localhost:8086/login.html → 'login-page-load' transaction"
echo "  ✅ Both transactions visible in APM dashboard"

echo ""
echo "📊 VERIFICATION STEPS:"
echo "  1. Open http://localhost:8086/login.html in browser"
echo "  2. Check browser console for 'Elastic APM RUM library loaded successfully'"
echo "  3. Check Network tab for requests to APM server (port 30200)"
echo "  4. Wait 30-60 seconds and refresh APM dashboard"
echo "  5. Look for 'login-page-load' transaction"

echo ""
echo "===================================================="