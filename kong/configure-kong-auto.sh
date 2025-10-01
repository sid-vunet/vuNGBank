#!/bin/bash

# Kong Gateway Configuration Script for VuNG Bank
# This script configures Kong services and routes automatically during startup
#
# CRITICAL ROUTES FOR APM MONITORING:
# - /elastic-apm-rum.js: Required for Elastic APM RUM library (frontend monitoring)
# - /login.html: Login page must be accessible for RUM transactions to appear
# - /index.html: Main page for RUM transaction tracking
# - /dashboard.html, /FundTransfer.html: Additional pages with RUM monitoring
#
# TROUBLESHOOTING NOTES:
# - If login-page-load transactions don't appear in APM, check:
#   1. Kong routes for /login.html (should return 200 OK)
#   2. Kong routes for /elastic-apm-rum.js (RUM library access)
#   3. JavaScript syntax in login.html (proper try-catch blocks)
# - All frontend routes must use strip_path=false to preserve URL structure
# - RUM library route is essential for APM functionality

KONG_ADMIN_URL="http://localhost:8001"
MAX_RETRIES=30
RETRY_DELAY=2

echo "=== Kong Gateway Configuration for VuNG Bank ==="
echo "Waiting for Kong Admin API to be ready..."

# Wait for Kong Admin API to be available
for i in $(seq 1 $MAX_RETRIES); do
    if curl -s "$KONG_ADMIN_URL" > /dev/null 2>&1; then
        echo "✅ Kong Admin API is ready"
        break
    fi
    
    if [ $i -eq $MAX_RETRIES ]; then
        echo "❌ Kong Admin API not available after $MAX_RETRIES attempts"
        exit 1
    fi
    
    echo "⏳ Waiting for Kong... (attempt $i/$MAX_RETRIES)"
    sleep $RETRY_DELAY
done

# Function to create or update a service
create_or_update_service() {
    local name=$1
    local url=$2
    
    echo "🔧 Configuring service: $name -> $url"
    
    # Check if service exists by checking HTTP status code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/services/$name")
    
    if [ "$http_code" = "200" ]; then
        # Update existing service
        curl -s -X PATCH \
            --url "$KONG_ADMIN_URL/services/$name" \
            --data "url=$url" \
            --data "retries=3" \
            --data "read_timeout=60000" \
            --data "write_timeout=60000" \
            --data "connect_timeout=60000" > /dev/null
        echo "✅ Updated service: $name"
    else
        # Create new service
        curl -s -X POST \
            --url "$KONG_ADMIN_URL/services/" \
            --data "name=$name" \
            --data "url=$url" \
            --data "retries=3" \
            --data "read_timeout=60000" \
            --data "write_timeout=60000" \
            --data "connect_timeout=60000" > /dev/null
        echo "✅ Created service: $name"
    fi
}

# Function to create a route
create_route() {
    local service_name=$1
    local path=$2
    
    echo "🛣️  Creating route: $path -> $service_name"
    
    # Check if service exists first
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/services/$service_name")
    if [ "$http_code" != "200" ]; then
        echo "❌ Service $service_name not found, skipping route creation"
        return 1
    fi
    
    # Delete existing routes for this service with the same path (to avoid duplicates)
    existing_routes=$(curl -s "$KONG_ADMIN_URL/services/$service_name/routes" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    target_path = '$path'
    for route in data.get('data', []):
        if target_path in route.get('paths', []):
            print(route['id'])
except:
    pass
" 2>/dev/null || true)
    
    for route_id in $existing_routes; do
        if [ -n "$route_id" ]; then
            curl -s -X DELETE "$KONG_ADMIN_URL/routes/$route_id" > /dev/null
        fi
    done
    
    # Create new route with high priority for API routes (preserve /api path)
    curl -s -X POST \
        --url "$KONG_ADMIN_URL/services/$service_name/routes" \
        --data "paths[]=$path" \
        --data "methods[]=GET" \
        --data "methods[]=POST" \
        --data "methods[]=PUT" \
        --data "methods[]=DELETE" \
        --data "strip_path=false" \
        --data "preserve_host=false" \
        --data "regex_priority=10" > /dev/null
    echo "✅ Route created: $path"
}

# Function to create route with path stripping
create_strip_route() {
    local service_name=$1
    local path=$2
    
    echo "🛣️  Creating strip route: $path -> $service_name"
    
    # Check if service exists first
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/services/$service_name")
    if [ "$http_code" != "200" ]; then
        echo "❌ Service $service_name not found, skipping route creation"
        return 1
    fi
    
    # Delete existing routes for this service first
    existing_routes=$(curl -s "$KONG_ADMIN_URL/services/$service_name/routes" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for route in data.get('data', []):
        print(route['id'])
except:
    pass
" 2>/dev/null || true)
    
    for route_id in $existing_routes; do
        if [ -n "$route_id" ]; then
            curl -s -X DELETE "$KONG_ADMIN_URL/routes/$route_id" > /dev/null
        fi
    done
    
    # Create route that strips the external path prefix
    curl -s -X POST \
        --url "$KONG_ADMIN_URL/services/$service_name/routes" \
        --data "paths[]=$path" \
        --data "methods[]=GET" \
        --data "methods[]=POST" \
        --data "methods[]=PUT" \
        --data "methods[]=DELETE" \
        --data "strip_path=true" \
        --data "preserve_host=false" \
        --data "regex_priority=10" > /dev/null
    echo "✅ Strip route created: $path"
}

# Function to create accounts route (special mapping)
create_accounts_route() {
    local service_name=$1
    local external_path=$2
    local internal_path=$3
    
    echo "🛣️  Creating accounts route: $external_path -> $service_name ($internal_path)"
    
    # Check if service exists first
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/services/$service_name")
    if [ "$http_code" != "200" ]; then
        echo "❌ Service $service_name not found, skipping route creation"
        return 1
    fi
    
    # Delete existing routes for this service first
    existing_routes=$(curl -s "$KONG_ADMIN_URL/services/$service_name/routes" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for route in data.get('data', []):
        print(route['id'])
except:
    pass
" 2>/dev/null || true)
    
    for route_id in $existing_routes; do
        if [ -n "$route_id" ]; then
            curl -s -X DELETE "$KONG_ADMIN_URL/routes/$route_id" > /dev/null
        fi
    done
    
    # Create route that strips external path and forwards to internal path
    curl -s -X POST \
        --url "$KONG_ADMIN_URL/services/$service_name/routes" \
        --data "paths[]=$external_path" \
        --data "methods[]=GET" \
        --data "methods[]=POST" \
        --data "methods[]=PUT" \
        --data "methods[]=DELETE" \
        --data "strip_path=true" \
        --data "preserve_host=false" \
        --data "regex_priority=10" > /dev/null
    echo "✅ Accounts route created: $external_path"
}

# Function to create frontend route (special case)
create_frontend_route() {
    local service_name=$1
    local path=$2
    
    echo "🌐 Creating frontend route: $path -> $service_name"
    
    # Check if service exists first
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$KONG_ADMIN_URL/services/$service_name")
    if [ "$http_code" != "200" ]; then
        echo "❌ Service $service_name not found, skipping frontend route creation"
        return 1
    fi
    
    # Delete existing routes for frontend service
    existing_routes=$(curl -s "$KONG_ADMIN_URL/services/$service_name/routes" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for route in data.get('data', []):
        print(route['id'])
except:
    pass
" 2>/dev/null || true)
    
    for route_id in $existing_routes; do
        if [ -n "$route_id" ]; then
            curl -s -X DELETE "$KONG_ADMIN_URL/routes/$route_id" > /dev/null
        fi
    done
    
    # Create frontend route with low priority (catch-all)
    curl -s -X POST \
        --url "$KONG_ADMIN_URL/services/$service_name/routes" \
        --data "paths[]=$path" \
        --data "methods[]=GET" \
        --data "methods[]=POST" \
        --data "methods[]=PUT" \
        --data "methods[]=DELETE" \
        --data "strip_path=false" \
        --data "preserve_host=false" \
        --data "regex_priority=0" > /dev/null
    echo "✅ Frontend route created: $path"
}

echo "🚀 Configuring Kong services with correct container names..."

# Configure backend services (using actual container names and ports from docker-compose)
create_or_update_service "accounts-service" "http://accounts-go-service:8002/internal/accounts"
create_or_update_service "login-python-authenticator" "http://login-python-authenticator:8001"  
create_or_update_service "login-go-service" "http://login-go-service:8000"
create_or_update_service "corebanking-java-service" "http://corebanking-java-service:8005"
create_or_update_service "payment-process-java-service" "http://payment-process-java-service:8004/payments"
create_or_update_service "payee-store-dotnet-service" "http://payee-store-dotnet-service:5004"
create_or_update_service "pdf-receipt-java-service" "http://pdf-receipt-java-service:8003"
create_or_update_service "frontend-service" "http://vubank-html-frontend:80"

# Configure Kong Admin services (internal routing within same container)
create_or_update_service "kong-admin-api" "http://localhost:8001"
create_or_update_service "kong-admin-gui" "http://localhost:8002"

echo "🛣️  Configuring Kong routes..."

# Configure API routes
create_accounts_route "accounts-service" "/api/accounts" "/internal/accounts"
create_route "login-python-authenticator" "/api/auth"
create_route "login-go-service" "/api/login"
create_route "login-go-service" "/api/logout"
create_route "corebanking-java-service" "/api/corebanking"
create_strip_route "payment-process-java-service" "/api/payments"
create_route "payee-store-dotnet-service" "/api/payees"
create_route "pdf-receipt-java-service" "/api/pdf"

# Configure Kong Admin routes
create_strip_route "kong-admin-api" "/kong/api"

# Kong Admin GUI has resource loading issues when served through proxy paths
# The GUI expects to be served from root and loads resources with absolute paths
echo "⚠️  Kong Admin GUI resource loading limitations detected"
echo "📍 For full functionality, use direct access:"
echo "    • Admin GUI (Direct): http://localhost:8002"
echo "    • Admin GUI (External): http://91.203.133.240:8002"

# Still create a basic GUI route for reference, but with known limitations
echo "🎛️  Creating basic Kong Admin GUI route (limited functionality)"
create_strip_route "kong-admin-gui" "/kong/gui"



# Configure frontend routes (root and specific HTML pages)
create_frontend_route "frontend-service" "/"

# Add specific routes for all HTML pages that use dynamic URLs
echo "🌐 Adding specific HTML page routes with dynamic URL support..."
html_pages=("index.html" "login.html" "dashboard.html" "FundTransfer.html")

for page in "${html_pages[@]}"; do
    echo "🔗 Creating route for /$page"
    curl -s -X POST \
        --url "$KONG_ADMIN_URL/services/frontend-service/routes" \
        --data "paths[]=/$page" \
        --data "methods[]=GET" \
        --data "strip_path=false" \
        --data "preserve_host=false" \
        --data "regex_priority=5" > /dev/null
    echo "✅ Route created for /$page"
done

# Add critical route for Elastic APM RUM library
echo "📊 Adding Elastic APM RUM library route..."
echo "🔗 Creating route for /elastic-apm-rum.js"
curl -s -X POST \
    --url "$KONG_ADMIN_URL/services/frontend-service/routes" \
    --data "paths[]=/elastic-apm-rum.js" \
    --data "methods[]=GET" \
    --data "strip_path=false" \
    --data "preserve_host=false" \
    --data "regex_priority=5" > /dev/null
echo "✅ Route created for /elastic-apm-rum.js (required for APM monitoring)"

echo "🎉 Kong Gateway configuration completed successfully!"

# Verify configuration
echo ""
echo "📊 Kong Configuration Summary:"
echo "Services configured: $(curl -s "$KONG_ADMIN_URL/services" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))" 2>/dev/null || echo "Unknown")"
echo "Routes configured: $(curl -s "$KONG_ADMIN_URL/routes" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))" 2>/dev/null || echo "Unknown")"

echo ""
echo "🔗 VuNG Bank Access Points (All with Dynamic URL Support):"
echo "  🌐 Main Portal:    http://localhost:8086/"
echo "  🏠 Index Page:     http://localhost:8086/index.html"
echo "  🔐 Login:          http://localhost:8086/login.html"
echo "  📊 Dashboard:      http://localhost:8086/dashboard.html"  
echo "  💸 Fund Transfer:  http://localhost:8086/FundTransfer.html"
echo "  🏥 Health Check:   http://localhost:8086/health"
echo ""
echo "  ✨ All pages now use window.location.origin for API calls"
echo "  ✨ Works with any domain/IP: 91.203.133.240:8086, localhost:8086, etc."
echo ""
echo "🛠️  Kong Management:"
echo "  📡 Admin API (Direct):    http://localhost:8001"
echo "  📡 Admin API (via Kong):  http://localhost:8086/kong/api"
echo "  🎛️  Admin GUI (Direct):    http://localhost:8002 ⭐ RECOMMENDED"
echo "  🎛️  Admin GUI (External):  http://91.203.133.240:8002 ⭐ RECOMMENDED"
echo ""
echo "  ⚠️  Note: /kong/gui route has limited functionality due to resource loading issues"
echo "  ✅ For full Kong Manager features, use direct access on port 8002"

# Test a simple endpoint
echo ""
echo "🧪 Testing Kong Gateway..."
if curl -s "http://localhost:8086/health" | grep -q "healthy"; then
    echo "✅ Kong Gateway is working properly!"
else
    echo "⚠️  Kong Gateway test failed - check service connectivity"
fi

# Validate critical APM routes
echo ""
echo "🔍 Validating critical APM routes..."

# Test login.html accessibility
login_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8086/login.html")
if [ "$login_status" = "200" ]; then
    echo "✅ login.html accessible (required for login-page-load transactions)"
else
    echo "❌ login.html not accessible ($login_status) - APM login transactions will fail"
fi

# Test index.html accessibility  
index_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8086/index.html")
if [ "$index_status" = "200" ]; then
    echo "✅ index.html accessible (required for vubank-index-page-load transactions)"
else
    echo "❌ index.html not accessible ($index_status) - APM index transactions will fail"
fi

# Test RUM library accessibility
rum_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8086/elastic-apm-rum.js")
if [ "$rum_status" = "200" ]; then
    echo "✅ elastic-apm-rum.js accessible (required for all APM monitoring)"
else
    echo "❌ elastic-apm-rum.js not accessible ($rum_status) - APM monitoring will not work"
fi

echo ""
if [ "$login_status" = "200" ] && [ "$index_status" = "200" ] && [ "$rum_status" = "200" ]; then
    echo "🎉 All critical APM routes are working! Both vubank-index-page-load and login-page-load transactions should appear in APM."
else
    echo "⚠️  Some critical routes failed - APM monitoring may be incomplete."
fi

echo "========================="

# Provide troubleshooting information
echo ""
echo "🛠️  TROUBLESHOOTING GUIDE:"
echo "If APM transactions are missing after Kong restart:"
echo ""
echo "1. Check route status:"
echo "   curl -s http://localhost:8001/routes | jq -r '.data[] | \"\\(.service.id) \\(.paths[0] // \"no-path\")\"'"
echo ""
echo "2. Re-run this script to restore routes:"
echo "   ./kong/configure-kong-auto.sh"
echo ""
echo "3. Verify critical routes manually:"
echo "   curl -I http://localhost:8086/login.html"
echo "   curl -I http://localhost:8086/index.html" 
echo "   curl -I http://localhost:8086/elastic-apm-rum.js"
echo ""
echo "4. If routes are missing, recreate them:"
echo "   # Frontend service route"
echo "   curl -X POST http://localhost:8001/services/frontend-service/routes \\"
echo "     --data 'paths[]=/login.html' --data 'methods[]=GET' --data 'strip_path=false'"
echo ""
echo "   # RUM library route"  
echo "   curl -X POST http://localhost:8001/services/frontend-service/routes \\"
echo "     --data 'paths[]=/elastic-apm-rum.js' --data 'methods[]=GET' --data 'strip_path=false'"
echo ""
echo "========================="