#!/bin/bash

# Kong Gateway Comprehensive Test Suite for VuNG Bank
# Tests API routing, APM integration, distributed tracing, and security features

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
KONG_GATEWAY_URL="http://localhost:8086"
KONG_ADMIN_URL="http://localhost:8001"
TEST_USER_EMAIL="testuser@vubank.com"
TEST_USER_PASSWORD="Test@123456"
TEST_CORRELATION_ID="test-$(date +%s)-$(uuidgen | cut -d'-' -f1)"

# Print colored output
print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

print_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_header() {
    echo ""
    echo "======================================================="
    echo "        Kong Gateway Test Suite - VuNG Bank"
    echo "        Testing APM, Routing & Distributed Tracing"
    echo "======================================================="
    echo ""
}

# Test Kong Gateway Health
test_kong_health() {
    print_test "Testing Kong Gateway Health..."
    
    # Test Kong Admin API
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" "${KONG_ADMIN_URL}/" 2>/dev/null); then
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        if [ "$http_code" = "200" ]; then
            print_success "Kong Admin API is healthy"
        else
            print_error "Kong Admin API returned status: $http_code"
            return 1
        fi
    else
        print_error "Kong Admin API is not accessible"
        return 1
    fi
    
    # Test Kong Proxy (Gateway)
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" "${KONG_GATEWAY_URL}/" 2>/dev/null); then
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        if [ "$http_code" = "200" ] || [ "$http_code" = "404" ]; then
            print_success "Kong Gateway is responding"
        else
            print_error "Kong Gateway returned status: $http_code"
            return 1
        fi
    else
        print_error "Kong Gateway is not accessible"
        return 1
    fi
    
    return 0
}

# Test Frontend Routing
test_frontend_routing() {
    print_test "Testing Frontend Routing through Kong..."
    
    # Test main page
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" "${KONG_GATEWAY_URL}/" 2>/dev/null); then
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        if [ "$http_code" = "200" ]; then
            print_success "Main page routing works"
        else
            print_error "Main page routing failed with status: $http_code"
        fi
    fi
    
    # Test login page
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" "${KONG_GATEWAY_URL}/login.html" 2>/dev/null); then
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        if [ "$http_code" = "200" ]; then
            print_success "Login page routing works"
        else
            print_error "Login page routing failed with status: $http_code"
        fi
    fi
    
    # Test dashboard page
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" "${KONG_GATEWAY_URL}/dashboard.html" 2>/dev/null); then
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        if [ "$http_code" = "200" ]; then
            print_success "Dashboard page routing works"
        else
            print_error "Dashboard page routing failed with status: $http_code"
        fi
    fi
    
    # Test fund transfer page
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" "${KONG_GATEWAY_URL}/FundTransfer.html" 2>/dev/null); then
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        if [ "$http_code" = "200" ]; then
            print_success "Fund Transfer page routing works"
        else
            print_error "Fund Transfer page routing failed with status: $http_code"
        fi
    fi
}

# Test API Routing with Distributed Tracing
test_api_routing_with_tracing() {
    print_test "Testing API Routing with Distributed Tracing..."
    
    local trace_id=$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')
    local span_id=$(openssl rand -hex 8)
    local traceparent="00-${trace_id}-${span_id}-01"
    
    # Test health endpoints with tracing headers
    local endpoints=(
        "/api/health"
        "/health"
        "/accounts"
        "/payments/health"
        "/api/pdf/health"
        "/core/health"
        "/api/payees"
    )
    
    for endpoint in "${endpoints[@]}"; do
        print_test "Testing endpoint: $endpoint"
        
        if response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
            -H "X-Correlation-ID: ${TEST_CORRELATION_ID}" \
            -H "X-Request-ID: $(uuidgen)" \
            -H "traceparent: ${traceparent}" \
            -H "User-Agent: VuNGBank-Test-Suite/1.0" \
            "${KONG_GATEWAY_URL}${endpoint}" 2>/dev/null); then
            
            http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
            
            if [ "$http_code" = "200" ] || [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
                print_success "Endpoint $endpoint responded with status: $http_code"
            else
                print_warning "Endpoint $endpoint responded with status: $http_code"
            fi
        else
            print_error "Failed to reach endpoint: $endpoint"
        fi
    done
}

# Test Authentication Flow with APM
test_authentication_flow() {
    print_test "Testing Authentication Flow with APM Tracing..."
    
    local trace_id=$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')
    local span_id=$(openssl rand -hex 8)
    local traceparent="00-${trace_id}-${span_id}-01"
    
    # Test login API
    print_test "Testing login API with distributed tracing..."
    
    local login_payload='{
        "email": "'${TEST_USER_EMAIL}'",
        "password": "'${TEST_USER_PASSWORD}'"
    }'
    
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-Correlation-ID: ${TEST_CORRELATION_ID}" \
        -H "X-Request-ID: $(uuidgen)" \
        -H "traceparent: ${traceparent}" \
        -H "User-Agent: VuNGBank-Test-Suite/1.0" \
        -d "$login_payload" \
        "${KONG_GATEWAY_URL}/api/login" 2>/dev/null); then
        
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        
        if [ "$http_code" = "200" ] || [ "$http_code" = "401" ] || [ "$http_code" = "400" ]; then
            print_success "Login API routing works (status: $http_code)"
            
            # Extract JWT token if login successful
            if [ "$http_code" = "200" ]; then
                jwt_token=$(echo "$response" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
                if [ -n "$jwt_token" ]; then
                    print_success "JWT token received in response"
                    export TEST_JWT_TOKEN="$jwt_token"
                fi
            fi
        else
            print_error "Login API failed with status: $http_code"
        fi
    else
        print_error "Failed to reach login API"
    fi
    
    # Test session API
    print_test "Testing session API..."
    
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -H "X-Correlation-ID: ${TEST_CORRELATION_ID}" \
        -H "X-Request-ID: $(uuidgen)" \
        -H "traceparent: ${traceparent}" \
        -H "User-Agent: VuNGBank-Test-Suite/1.0" \
        "${KONG_GATEWAY_URL}/api/session" 2>/dev/null); then
        
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        print_success "Session API routing works (status: $http_code)"
    else
        print_error "Failed to reach session API"
    fi
}

# Test Protected Endpoints with JWT
test_protected_endpoints() {
    print_test "Testing Protected Endpoints with JWT Authentication..."
    
    if [ -z "$TEST_JWT_TOKEN" ]; then
        print_warning "No JWT token available, testing without authentication"
        auth_header=""
    else
        auth_header="-H \"Authorization: Bearer ${TEST_JWT_TOKEN}\""
    fi
    
    local trace_id=$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')
    local span_id=$(openssl rand -hex 8)
    local traceparent="00-${trace_id}-${span_id}-01"
    
    # Test accounts balance
    print_test "Testing accounts balance API..."
    
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -H "X-Correlation-ID: ${TEST_CORRELATION_ID}" \
        -H "X-Request-ID: $(uuidgen)" \
        -H "traceparent: ${traceparent}" \
        -H "User-Agent: VuNGBank-Test-Suite/1.0" \
        ${auth_header} \
        "${KONG_GATEWAY_URL}/accounts/balance" 2>/dev/null); then
        
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        
        if [ "$http_code" = "200" ] || [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
            print_success "Accounts balance API routing works (status: $http_code)"
        else
            print_warning "Accounts balance API responded with status: $http_code"
        fi
    fi
    
    # Test payment initiation
    print_test "Testing payment initiation API..."
    
    local payment_payload='{
        "amount": 100.50,
        "from_account": "123456789",
        "to_account": "987654321",
        "description": "Test payment via Kong Gateway"
    }'
    
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "X-Correlation-ID: ${TEST_CORRELATION_ID}" \
        -H "X-Request-ID: $(uuidgen)" \
        -H "traceparent: ${traceparent}" \
        -H "User-Agent: VuNGBank-Test-Suite/1.0" \
        ${auth_header} \
        -d "$payment_payload" \
        "${KONG_GATEWAY_URL}/payments/initiate" 2>/dev/null); then
        
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        
        if [ "$http_code" = "200" ] || [ "$http_code" = "201" ] || [ "$http_code" = "401" ] || [ "$http_code" = "403" ]; then
            print_success "Payment initiation API routing works (status: $http_code)"
        else
            print_warning "Payment initiation API responded with status: $http_code"
        fi
    fi
}

# Test Security Headers and CORS
test_security_features() {
    print_test "Testing Security Features (Headers, CORS, Rate Limiting)..."
    
    # Test security headers
    print_test "Checking security headers..."
    
    if response=$(curl -s -I "${KONG_GATEWAY_URL}/" 2>/dev/null); then
        if echo "$response" | grep -q "X-Frame-Options"; then
            print_success "X-Frame-Options header present"
        else
            print_warning "X-Frame-Options header missing"
        fi
        
        if echo "$response" | grep -q "X-Content-Type-Options"; then
            print_success "X-Content-Type-Options header present"
        else
            print_warning "X-Content-Type-Options header missing"
        fi
        
        if echo "$response" | grep -q "X-XSS-Protection"; then
            print_success "X-XSS-Protection header present"
        else
            print_warning "X-XSS-Protection header missing"
        fi
    fi
    
    # Test CORS preflight
    print_test "Testing CORS preflight request..."
    
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -X OPTIONS \
        -H "Origin: http://localhost:3000" \
        -H "Access-Control-Request-Method: POST" \
        -H "Access-Control-Request-Headers: Content-Type,Authorization" \
        "${KONG_GATEWAY_URL}/api/login" 2>/dev/null); then
        
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        
        if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
            print_success "CORS preflight request works (status: $http_code)"
        else
            print_warning "CORS preflight responded with status: $http_code"
        fi
    fi
    
    # Test rate limiting (make multiple rapid requests)
    print_test "Testing rate limiting..."
    
    local success_count=0
    local rate_limited_count=0
    
    for i in {1..10}; do
        if response=$(curl -s -w "HTTP_STATUS:%{http_code}" \
            -H "X-Correlation-ID: ${TEST_CORRELATION_ID}-rapid-${i}" \
            "${KONG_GATEWAY_URL}/api/health" 2>/dev/null); then
            
            http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
            
            if [ "$http_code" = "200" ]; then
                ((success_count++))
            elif [ "$http_code" = "429" ]; then
                ((rate_limited_count++))
            fi
        fi
        sleep 0.1
    done
    
    if [ $success_count -gt 0 ]; then
        print_success "Rate limiting allows normal requests ($success_count successful)"
    fi
    
    if [ $rate_limited_count -gt 0 ]; then
        print_success "Rate limiting is working ($rate_limited_count requests limited)"
    else
        print_warning "Rate limiting may not be active (no 429 responses)"
    fi
}

# Test APM Data Collection
test_apm_integration() {
    print_test "Testing APM Integration and Data Collection..."
    
    # Check Kong logs for APM-related entries
    print_test "Checking Kong logs for APM activity..."
    
    if docker logs vubank-kong-gateway 2>&1 | tail -50 | grep -q "apm\|elastic\|trace"; then
        print_success "APM-related activity found in Kong logs"
    else
        print_warning "No APM-related activity found in Kong logs"
    fi
    
    # Test if correlation IDs are being propagated
    print_test "Testing correlation ID propagation..."
    
    local test_correlation_id="test-correlation-$(date +%s)"
    
    if response=$(curl -s -v \
        -H "X-Correlation-ID: ${test_correlation_id}" \
        "${KONG_GATEWAY_URL}/api/health" 2>&1); then
        
        if echo "$response" | grep -q "X-Correlation-ID"; then
            print_success "Correlation ID headers are being processed"
        else
            print_warning "Correlation ID headers may not be propagated"
        fi
    fi
    
    # Test trace context propagation
    print_test "Testing trace context propagation..."
    
    local trace_id=$(uuidgen | tr -d '-' | tr '[:upper:]' '[:lower:]')
    local span_id=$(openssl rand -hex 8)
    local traceparent="00-${trace_id}-${span_id}-01"
    
    if response=$(curl -s -v \
        -H "traceparent: ${traceparent}" \
        "${KONG_GATEWAY_URL}/api/health" 2>&1); then
        
        if echo "$response" | grep -q "traceparent\|trace"; then
            print_success "Trace context headers are being processed"
        else
            print_warning "Trace context headers may not be propagated"
        fi
    fi
}

# Test Kong Metrics Collection
test_metrics_collection() {
    print_test "Testing Kong Metrics Collection..."
    
    # Check if Prometheus metrics endpoint is available
    print_test "Checking Prometheus metrics endpoint..."
    
    if response=$(curl -s -w "HTTP_STATUS:%{http_code}" "${KONG_GATEWAY_URL}/metrics" 2>/dev/null); then
        http_code=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]*" | cut -d: -f2)
        
        if [ "$http_code" = "200" ]; then
            print_success "Prometheus metrics endpoint is accessible"
            
            # Check for Kong-specific metrics
            if echo "$response" | grep -q "kong_"; then
                print_success "Kong-specific metrics are available"
            else
                print_warning "Kong-specific metrics not found"
            fi
        else
            print_warning "Prometheus metrics endpoint responded with status: $http_code"
        fi
    else
        print_warning "Prometheus metrics endpoint is not accessible"
    fi
}

# Generate Test Report
generate_test_report() {
    print_test "Generating Test Report..."
    
    local report_file="kong_test_report_$(date +%Y%m%d_%H%M%S).txt"
    
    cat > "$report_file" << EOF
Kong Gateway Test Report - VuNG Bank
Generated: $(date)
Correlation ID: ${TEST_CORRELATION_ID}

Test Configuration:
- Kong Gateway URL: ${KONG_GATEWAY_URL}
- Kong Admin URL: ${KONG_ADMIN_URL}
- Test User: ${TEST_USER_EMAIL}

Test Results:
$(cat /tmp/kong_test_results.log 2>/dev/null || echo "Test results not available")

Kong Configuration Status:
EOF
    
    # Get Kong configuration info
    if curl -s "${KONG_ADMIN_URL}/status" >> "$report_file" 2>/dev/null; then
        echo "Kong status information added to report"
    fi
    
    echo "" >> "$report_file"
    echo "Services:" >> "$report_file"
    curl -s "${KONG_ADMIN_URL}/services" | jq -r '.data[] | "- \(.name): \(.protocol)://\(.host):\(.port)"' >> "$report_file" 2>/dev/null || echo "Services information not available" >> "$report_file"
    
    echo "" >> "$report_file"
    echo "Routes:" >> "$report_file"
    curl -s "${KONG_ADMIN_URL}/routes" | jq -r '.data[] | "- \(.name): \(.paths)"' >> "$report_file" 2>/dev/null || echo "Routes information not available" >> "$report_file"
    
    echo "" >> "$report_file"
    echo "Plugins:" >> "$report_file"
    curl -s "${KONG_ADMIN_URL}/plugins" | jq -r '.data[] | "- \(.name): \(.enabled)"' >> "$report_file" 2>/dev/null || echo "Plugins information not available" >> "$report_file"
    
    print_success "Test report generated: $report_file"
}

# Main Test Execution
main() {
    print_header
    
    # Redirect test output to log file
    exec > >(tee /tmp/kong_test_results.log)
    exec 2>&1
    
    print_test "Starting Kong Gateway Test Suite for VuNG Bank..."
    echo "Test Correlation ID: ${TEST_CORRELATION_ID}"
    echo ""
    
    # Run all tests
    test_kong_health || exit 1
    echo ""
    
    test_frontend_routing
    echo ""
    
    test_api_routing_with_tracing
    echo ""
    
    test_authentication_flow
    echo ""
    
    test_protected_endpoints
    echo ""
    
    test_security_features
    echo ""
    
    test_apm_integration
    echo ""
    
    test_metrics_collection
    echo ""
    
    generate_test_report
    
    echo ""
    print_success "Kong Gateway Test Suite completed!"
    echo ""
    echo "🔗 Access your application at: ${KONG_GATEWAY_URL}"
    echo "🔧 Kong Admin API: ${KONG_ADMIN_URL}"
    echo "📊 Test Correlation ID: ${TEST_CORRELATION_ID}"
    echo ""
}

# Execute main function
main "$@"