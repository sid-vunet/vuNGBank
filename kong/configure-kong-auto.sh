#!/bin/bash

# Kong Gateway Configuration Script for VuNG Bank
# This script configures Kong services and routes automatically during startup

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
    
    # Delete existing routes for this service first (to avoid duplicates)
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

echo "🛣️  Configuring Kong routes..."

# Configure API routes
create_accounts_route "accounts-service" "/api/accounts" "/internal/accounts"
create_route "login-python-authenticator" "/api/auth"
create_route "login-go-service" "/api/login"
create_route "corebanking-java-service" "/api/corebanking"
create_strip_route "payment-process-java-service" "/api/payments"
create_route "payee-store-dotnet-service" "/api/payees"
create_route "pdf-receipt-java-service" "/api/pdf"

# Configure frontend route (special handling)
create_frontend_route "frontend-service" "/"

echo "🎉 Kong Gateway configuration completed successfully!"

# Verify configuration
echo ""
echo "📊 Kong Configuration Summary:"
echo "Services configured: $(curl -s "$KONG_ADMIN_URL/services" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))" 2>/dev/null || echo "Unknown")"
echo "Routes configured: $(curl -s "$KONG_ADMIN_URL/routes" | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))" 2>/dev/null || echo "Unknown")"

echo ""
echo "🔗 VuNG Bank Access Points:"
echo "  🌐 Main Portal:    http://localhost:8086/"
echo "  🔐 Login:          http://localhost:8086/login.html"
echo "  📊 Dashboard:      http://localhost:8086/dashboard.html"  
echo "  💸 Transfer:       http://localhost:8086/FundTransfer.html"
echo "  🏥 Health Check:   http://localhost:8086/health"
echo ""
echo "🛠️  Kong Management:"
echo "  📡 Admin API:      http://localhost:8001"
echo "  🎛️  Admin GUI:      http://localhost:8002"

# Test a simple endpoint
echo ""
echo "🧪 Testing Kong Gateway..."
if curl -s "http://localhost:8086/health" | grep -q "healthy"; then
    echo "✅ Kong Gateway is working properly!"
else
    echo "⚠️  Kong Gateway test failed - check service connectivity"
fi

echo "========================="