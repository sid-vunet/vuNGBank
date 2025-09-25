#!/bin/bash

# Kong API Gateway Service Reconfiguration for VuNG Bank
# Fix service names to match actual container names

KONG_ADMIN_URL="http://localhost:8001"

echo "=== Reconfiguring Kong Services with Correct Container Names ==="

# Function to delete all existing services and routes
delete_all_services() {
    echo "Deleting existing services..."
    # Get all service IDs and delete them
    services=$(curl -s "${KONG_ADMIN_URL}/services" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for service in data.get('data', []):
    print(service['id'])
")
    
    for service_id in $services; do
        echo "Deleting service: $service_id"
        curl -X DELETE "${KONG_ADMIN_URL}/services/$service_id"
    done
    
    echo "All services deleted"
}

# Function to create a service
create_service() {
    local name=$1
    local url=$2
    
    echo "Creating service: $name -> $url"
    curl -i -X POST \
        --url "${KONG_ADMIN_URL}/services/" \
        --data "name=${name}" \
        --data "url=${url}" \
        --data "retries=3" \
        --data "read_timeout=60000" \
        --data "write_timeout=60000" \
        --data "connect_timeout=60000"
    echo -e "\n"
}

# Function to create a route
create_route() {
    local service_name=$1
    local path=$2
    
    echo "Creating route for service: $service_name with path: $path"
    curl -i -X POST \
        --url "${KONG_ADMIN_URL}/services/${service_name}/routes" \
        --data "paths[]=${path}" \
        --data "methods[]=GET" \
        --data "methods[]=POST" \
        --data "methods[]=PUT" \
        --data "methods[]=DELETE" \
        --data "strip_path=true" \
        --data "preserve_host=false"
    echo -e "\n"
}

# Delete existing services first
delete_all_services

# Create services with correct container names from docker-compose
create_service "accounts-service" "http://accounts-go-service:8000"
create_service "login-python-authenticator" "http://login-python-authenticator:8001"
create_service "login-go-service" "http://login-go-service:8002"
create_service "corebanking-java-service" "http://corebanking-java-service:8003"
create_service "payment-process-java-service" "http://payment-process-java-service:8004" 
create_service "payee-store-dotnet-service" "http://payee-store-dotnet-service:5004"
create_service "pdf-receipt-java-service" "http://pdf-receipt-java-service:8005"
create_service "frontend-service" "http://vubank-html-frontend:80"

# Create routes
create_route "accounts-service" "/api/accounts"
create_route "login-python-authenticator" "/api/auth"
create_route "login-go-service" "/api/login"
create_route "corebanking-java-service" "/api/corebanking"
create_route "payment-process-java-service" "/api/payments"
create_route "payee-store-dotnet-service" "/api/payees"
create_route "pdf-receipt-java-service" "/api/receipts"
create_route "frontend-service" "/"

echo "=== Kong Reconfiguration Complete ==="

# Test a route
echo -e "\n=== Testing Configuration ==="
echo "Testing frontend service through Kong:"
curl -v http://localhost:8086/ 2>&1 | head -20

echo -e "\n=== Kong Gateway Endpoints ==="
echo "Kong Proxy Port: http://localhost:8086"
echo "Kong Admin API: http://localhost:8001"
echo ""
echo "Service Endpoints through Kong:"
echo "  Frontend:      http://localhost:8086/"
echo "  Accounts:      http://localhost:8086/api/accounts"
echo "  Authentication: http://localhost:8086/api/auth"
echo "  Login:         http://localhost:8086/api/login"
echo "  Core Banking:  http://localhost:8086/api/corebanking"
echo "  Payments:      http://localhost:8086/api/payments"
echo "  Payees:        http://localhost:8086/api/payees"
echo "  PDF Receipts:  http://localhost:8086/api/receipts"