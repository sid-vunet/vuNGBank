#!/bin/bash

# Quick fix script for APM-related Kong routes
# Use this script if login-page-load transactions are missing from APM

KONG_ADMIN_URL="http://localhost:8001"
KONG_GATEWAY_URL="http://localhost:8086"

echo "🔧 APM Routes Quick Fix for VuNG Bank"
echo "======================================"

# Check if Kong is running
if ! curl -s "$KONG_ADMIN_URL" > /dev/null 2>&1; then
    echo "❌ Kong Admin API not available at $KONG_ADMIN_URL"
    echo "   Please ensure Kong is running first"
    exit 1
fi

echo "✅ Kong Admin API is available"

# Check if frontend service exists
frontend_service=$(curl -s "$KONG_ADMIN_URL/services/frontend-service" 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ Frontend service not found - run full configure-kong-auto.sh first"
    exit 1
fi

echo "✅ Frontend service exists"

# Function to create route if missing
ensure_route() {
    local path=$1
    local description=$2
    
    echo "🔍 Checking route for $path..."
    
    # Test if route works
    status=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_GATEWAY_URL$path")
    
    if [ "$status" = "200" ]; then
        echo "✅ $description route working ($status)"
        return 0
    fi
    
    echo "❌ $description route failed ($status) - recreating..."
    
    # Create the route
    result=$(curl -s -X POST \
        --url "$KONG_ADMIN_URL/services/frontend-service/routes" \
        --data "paths[]=$path" \
        --data "methods[]=GET" \
        --data "strip_path=false" \
        --data "preserve_host=false" \
        --data "regex_priority=5")
    
    if echo "$result" | grep -q '"id"'; then
        echo "✅ $description route created successfully"
        
        # Test again
        sleep 1
        new_status=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_GATEWAY_URL$path")
        echo "   New status: $new_status"
    else
        echo "❌ Failed to create $description route"
        echo "   Response: $result"
    fi
}

# Ensure critical APM routes exist
echo ""
echo "🛣️  Ensuring critical APM routes..."

ensure_route "/login.html" "Login page"
ensure_route "/index.html" "Index page"  
ensure_route "/elastic-apm-rum.js" "RUM library"
ensure_route "/dashboard.html" "Dashboard page"
ensure_route "/FundTransfer.html" "Fund Transfer page"

echo ""
echo "🧪 Final validation..."

# Final test
login_ok=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_GATEWAY_URL/login.html")
index_ok=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_GATEWAY_URL/index.html")
rum_ok=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_GATEWAY_URL/elastic-apm-rum.js")

echo "Final status check:"
echo "  • Login page: $login_ok"
echo "  • Index page: $index_ok"
echo "  • RUM library: $rum_ok"

if [ "$login_ok" = "200" ] && [ "$index_ok" = "200" ] && [ "$rum_ok" = "200" ]; then
    echo ""
    echo "🎉 SUCCESS! All critical APM routes are working."
    echo "   Both 'vubank-index-page-load' and 'login-page-load' transactions should now appear in APM."
    echo ""
    echo "📋 Next steps:"
    echo "   1. Open http://localhost:8086/login.html in browser"
    echo "   2. Check browser console for RUM initialization messages"
    echo "   3. Wait 30-60 seconds for transactions to appear in APM dashboard"
else
    echo ""
    echo "⚠️  Some routes still not working. Check Kong Gateway and frontend container status."
fi

echo ""
echo "======================================"