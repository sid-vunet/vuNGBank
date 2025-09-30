#!/bin/bash

# VuNG Bank Service Management Script
# Usage: ./manage-services.sh [command]
# Commands: status, start, stop, restart, install, logs, health

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="/data1/apps/vuNGBank"
FRONTEND_DIR="$PROJECT_DIR/frontend"
FRONTEND_PORT=3001
BACKEND_API_PORT=8000

# APM Configuration - Export environment variables for Docker Compose
export ELASTIC_APM_SERVER_URL=${ELASTIC_APM_SERVER_URL:-"http://91.203.133.240:30200"}
export ELASTIC_APM_ENVIRONMENT="e2e-240-dev"
export ELASTIC_APM_SERVICE_VERSION=${ELASTIC_APM_SERVICE_VERSION:-"1.0.0"}
export ELASTIC_APM_TRANSACTION_SAMPLE_RATE=${ELASTIC_APM_TRANSACTION_SAMPLE_RATE:-"1.0"}
export ELASTIC_APM_SPAN_SAMPLE_RATE=${ELASTIC_APM_SPAN_SAMPLE_RATE:-"1.0"}
export ELASTIC_APM_CAPTURE_BODY=${ELASTIC_APM_CAPTURE_BODY:-"all"}
export ELASTIC_APM_CAPTURE_HEADERS=${ELASTIC_APM_CAPTURE_HEADERS:-"true"}
export ELASTIC_APM_USE_DISTRIBUTED_TRACING=${ELASTIC_APM_USE_DISTRIBUTED_TRACING:-"true"}
export ELASTIC_APM_LOG_LEVEL=${ELASTIC_APM_LOG_LEVEL:-"info"}
export ELASTIC_APM_RECORDING=${ELASTIC_APM_RECORDING:-"true"}
export ELASTIC_APM_STACK_TRACE_LIMIT=${ELASTIC_APM_STACK_TRACE_LIMIT:-"50"}
export ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION=${ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION:-"0ms"}

# Kong container health check
check_kong_container_health() {
    local container_name="vubank-kong-gateway"
    local max_wait=60
    local wait_time=0
    
    print_status "Checking Kong container health..."
    
    while [ $wait_time -lt $max_wait ]; do
        local container_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "not_found")
        
        case "$container_status" in
            "healthy")
                print_success "Kong container is healthy"
                return 0
                ;;
            "unhealthy")
                print_warning "Kong container is unhealthy, attempting restart..."
                restart_kong_container
                return $?
                ;;
            "starting")
                print_status "Kong container is starting... ($wait_time/$max_wait seconds)"
                ;;
            "not_found")
                print_warning "Kong container not found, starting it..."
                start_kong_container
                return $?
                ;;
        esac
        
        sleep 5
        wait_time=$((wait_time + 5))
    done
    
    print_error "Kong container health check timed out after $max_wait seconds"
    return 1
}

# Start Kong container if not running
start_kong_container() {
    print_status "Starting Kong Gateway container..."
    
    if docker compose --profile kong up vubank-kong-gateway -d; then
        print_success "Kong container started successfully"
        sleep 10  # Give Kong time to initialize
        return 0
    else
        print_error "Failed to start Kong container"
        return 1
    fi
}

# Restart Kong container
restart_kong_container() {
    print_status "Restarting Kong Gateway container..."
    
    docker compose --profile kong stop vubank-kong-gateway
    sleep 5
    
    if docker compose --profile kong up vubank-kong-gateway -d; then
        print_success "Kong container restarted successfully"
        sleep 15  # Give Kong more time to fully initialize after restart
        return 0
    else
        print_error "Failed to restart Kong container"
        return 1
    fi
}

# Configure Kong services and routes with validation and auto-recovery
configure_kong_services() {
    local max_retries=10
    local retry_count=0
    
    print_status "Configuring Kong Gateway services and routes..."
    
    # First, ensure Kong container is healthy
    if ! check_kong_container_health; then
        print_error "Kong container health check failed"
        return 1
    fi
    
    # Check if Kong configuration script exists
    if [ ! -f "kong/configure-kong-auto.sh" ]; then
        print_error "Kong configuration script not found at kong/configure-kong-auto.sh!"
        return 1
    fi
    
    # Make sure the script is executable
    chmod +x kong/configure-kong-auto.sh
    
    # Wait for Kong Admin API to be available with extended retries
    print_status "Waiting for Kong Admin API to be available..."
    while [ $retry_count -lt $max_retries ]; do
        if curl -s "http://localhost:8001" > /dev/null 2>&1; then
            print_success "Kong Admin API is ready"
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -eq $max_retries ]; then
            print_error "Kong Admin API not available after $max_retries attempts"
            print_status "Attempting Kong container restart..."
            if restart_kong_container; then
                print_status "Retrying Kong configuration after restart..."
                configure_kong_services  # Recursive call after restart
                return $?
            else
                return 1
            fi
        fi
        
        print_status "Waiting for Kong Admin API... (attempt $retry_count/$max_retries)"
        sleep 10
    done
    
    # Execute Kong configuration script
    print_status "Executing Kong configuration script..."
    if ./kong/configure-kong-auto.sh; then
        print_success "Kong Gateway services and routes configured successfully!"
        
        # Validate configuration
        validate_kong_configuration
    else
        print_error "Kong configuration script failed!"
        return 1
    fi
}

# Validate Kong configuration with comprehensive checks
validate_kong_configuration() {
    print_status "Validating Kong configuration..."
    
    # Check services count
    local services_count=$(curl -s "http://localhost:8001/services" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))" 2>/dev/null || echo "0")
    
    # Check routes count  
    local routes_count=$(curl -s "http://localhost:8001/routes" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)['data']))" 2>/dev/null || echo "0")
    
    if [ "$services_count" -gt "0" ] && [ "$routes_count" -gt "0" ]; then
        print_success "Kong configuration validated: $services_count services, $routes_count routes"
        
        # Test critical endpoints
        local endpoint_tests=0
        local endpoint_passes=0
        
        # Test main gateway health
        endpoint_tests=$((endpoint_tests + 1))
        if curl -s "http://localhost:8086/health" > /dev/null 2>&1; then
            endpoint_passes=$((endpoint_passes + 1))
            print_success "✅ Main gateway health endpoint working"
        else
            print_warning "❌ Main gateway health endpoint failed"
        fi
        
        # Test Kong Admin API through gateway
        endpoint_tests=$((endpoint_tests + 1))
        if curl -s "http://localhost:8086/kong/api" > /dev/null 2>&1; then
            endpoint_passes=$((endpoint_passes + 1))
            print_success "✅ Kong Admin API through gateway working"
        else
            print_warning "❌ Kong Admin API through gateway failed"
        fi
        
        # Test frontend route
        endpoint_tests=$((endpoint_tests + 1))
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8086/" | grep -q "200\|301\|302"; then
            endpoint_passes=$((endpoint_passes + 1))
            print_success "✅ Frontend route working"
        else
            print_warning "❌ Frontend route failed"
        fi
        
        # Summary
        print_status "Endpoint validation: $endpoint_passes/$endpoint_tests tests passed"
        
        if [ "$endpoint_passes" -ge 2 ]; then
            print_success "Kong Gateway validation passed with $endpoint_passes/$endpoint_tests endpoints working"
            return 0
        else
            print_warning "Kong Gateway partially working: $endpoint_passes/$endpoint_tests endpoints functional"
            return 1
        fi
    else
        print_error "Kong configuration validation failed: $services_count services, $routes_count routes"
        return 1
    fi
}

# Print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "        VuNG Bank Service Manager"
    echo "=========================================="
    echo ""
}

# Check service status
check_status() {
    print_header
    echo "🔍 Service Status Check:"
    echo ""
    
    # Check Docker services
    if ! docker compose ps >/dev/null 2>&1; then
        print_error "❌ Docker Compose not available"
        return 1
    fi
    
    # Check Kong API Gateway first
    if docker compose --profile kong ps | grep -q "vubank-kong-gateway.*Up"; then
        print_success "✅ Kong API Gateway (8086) - Running"
        
        # Additional Kong health check
        if curl -s "http://localhost:8001" > /dev/null 2>&1; then
            print_success "✅ Kong Admin API (8001) - Accessible"
        else
            print_warning "⚠️  Kong Admin API (8001) - Not Responding"
        fi
        
        if curl -s "http://localhost:8086/health" > /dev/null 2>&1; then
            print_success "✅ Kong Gateway Health Check - Passing"
        else
            print_warning "⚠️  Kong Gateway Health Check - Failing"
        fi
    else
        print_error "❌ Kong API Gateway (8086) - Not Running"
    fi
    
    if docker compose --profile kong ps | grep -q "kong-postgres.*Up"; then
        print_success "✅ Kong Database (internal) - Running"
    else
        print_error "❌ Kong Database (internal) - Not Running"
    fi
    
    # Check individual services
    if docker compose ps | grep -q "login-go-service.*Up"; then
        print_success "✅ Go Login Gateway (8000) - Running"
    else
        print_error "❌ Go Login Gateway (8000) - Not Running"
    fi
    
    if docker compose ps | grep -q "login-python-authenticator.*Up"; then
        print_success "✅ Python Auth Service (8001) - Running"
    else
        print_error "❌ Python Auth Service (8001) - Not Running"
    fi
    
    if docker compose ps | grep -q "accounts-go-service.*Up"; then
        print_success "✅ Go Accounts Service (8002) - Running"
    else
        print_error "❌ Go Accounts Service (8002) - Not Running"
    fi
    
    if docker compose ps | grep -q "pdf-receipt-java-service.*Up"; then
        print_success "✅ Java PDF Receipt Service (8003) - Running"
    else
        print_error "❌ Java PDF Receipt Service (8003) - Not Running"
    fi
    
    if docker compose ps | grep -q "corebanking-java-service.*Up"; then
        print_success "✅ Java CoreBanking Service (8005) - Running"
    else
        print_error "❌ Java CoreBanking Service (8005) - Not Running"
    fi

    if docker compose ps | grep -q "payment-process-java-service.*Up"; then
        print_success "✅ Java Payment Service (8004) - Running"
    else
        print_error "❌ Java Payment Service (8004) - Not Running"
    fi

    if docker compose ps | grep -q "payee-store-dotnet-service.*Up"; then
        print_success "✅ .NET Payee Service (5004) - Running"
    else
        print_error "❌ .NET Payee Service (5004) - Not Running"
    fi
    
    if docker compose ps | grep -q "vubank-postgres.*Up"; then
        print_success "✅ PostgreSQL Database (5432) - Running"
    else
        print_error "❌ PostgreSQL Database (5432) - Not Running"
    fi

    # Check HTML Frontend Container
    if docker ps | grep -q "vubank-html-frontend"; then
        print_success "✅ HTML Frontend (8086) - Running"
    else
        print_error "❌ HTML Frontend (8086) - Not Running"
    fi
    
    echo ""
    echo "🔗 Service URLs (All traffic through Kong Gateway):"
    echo "   🌐 MAIN ENTRY POINT: http://localhost:8086"
    echo ""
    echo "   Frontend Pages:"
    echo "     • Login:          http://localhost:8086/login.html"
    echo "     • Dashboard:      http://localhost:8086/dashboard.html"
    echo "     • Fund Transfer:  http://localhost:8086/FundTransfer.html"
    echo ""
    echo "   API Endpoints:"
    echo "     • Login API:      http://localhost:8086/api/login"
    echo "     • Logout API:     http://localhost:8086/api/logout"
    echo "     • Accounts API:   http://localhost:8086/api/accounts"
    echo "     • Payments API:   http://localhost:8086/api/payments"
    echo "     • PDF API:        http://localhost:8086/api/pdf"
    echo "     • Payees API:     http://localhost:8086/api/payees"
    echo "     • CoreBanking:    http://localhost:8086/api/corebanking"
    echo ""
    echo "   Management:"
    echo "     • Kong Admin API: http://localhost:8001"
    echo "     • Kong Admin GUI: http://localhost:8002"
    echo "     • Database:       localhost:5432"
    echo ""
}

# Start all services
start_services() {
    print_header
    print_status "Starting all services..."
    echo ""
    
    # Start with HTML frontend container
    start_services_with_html_container
}

# Start services with HTML container
start_services_with_html_container() {
    print_status "Starting services with Kong API Gateway and HTML frontend container..."
    
    # Build HTML container with fresh build (no cache)
    print_status "Building HTML frontend container (fresh build, no cache)..."
    cd frontend && chmod +x build-html-container.sh && ./build-html-container.sh && cd ..
    
    # Start Kong database and migration first
    print_status "Starting Kong database and running migrations..."
    docker compose --profile kong up kong-postgres kong-migrations -d --build
    
    # Wait for Kong database to be ready
    print_status "Waiting for Kong database to be ready..."
    sleep 10
    
    # Start all services with Kong and HTML frontend profiles (fresh build)
    print_status "Starting all services with Kong API Gateway (fresh build, no cache)..."
    docker compose --profile kong --profile html-frontend up -d --build
    
    # Wait for Kong to be ready and configure it automatically with validation
    print_status "Waiting for Kong API Gateway to be ready..."
    sleep 15
    
    # Auto-configure Kong services and routes with health checks
    print_status "Configuring Kong Gateway services and routes with validation..."
    if configure_kong_services; then
        print_success "Kong Gateway fully configured and validated!"
    else
        print_error "Kong Gateway configuration failed, but continuing..."
        print_status "You can manually reconfigure Kong later using: ./manage-services.sh configure"
    fi
    
    print_success "All services started with Kong API Gateway (port 8086) and HTML frontend!"
    echo ""
    print_status "🔗 Access your application at: http://localhost:8086"
    echo ""
    check_status
}

# Start services with React container  
# Stop all services
stop_services() {
    print_header
    print_status "Stopping all services..."
    echo ""
    
    # Stop Docker services (including Kong and HTML frontend containers)
    print_status "Stopping Docker services with Kong API Gateway..."
    docker compose --profile kong --profile html-frontend --profile frontend down --remove-orphans
    
    print_success "All services stopped!"
}

# Restart all services
restart_services() {
    print_header
    print_status "Restarting all services..."
    echo ""
    
    stop_services
    sleep 5
    start_services
    
    # Additional Kong configuration after restart
    print_status "Re-configuring Kong after restart..."
    configure_kong_services
}

# Install dependencies
install_dependencies() {
    print_header
    print_status "Installing dependencies..."
    echo ""
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! command -v docker compose >/dev/null 2>&1; then
        print_error "Docker Compose is not available. Please install Docker Compose."
        exit 1
    fi
    
    # Make scripts executable
    print_status "Making scripts executable..."
    chmod +x frontend-server.sh
    chmod +x manage-services.sh
    
    print_success "Dependencies installed!"
}

# Show logs
show_logs() {
    print_header
    echo "📋 Service Logs:"
    echo ""
    echo "Docker Services:"
    docker compose logs --tail=50
    echo ""
    echo "Frontend Server:"
    ./frontend-server.sh logs
}

# Health check
health_check() {
    print_header
    print_status "Running health checks..."
    echo ""
    
    # Check Docker health
    print_status "Checking Docker services..."
    docker compose ps
    
    echo ""
    print_status "Checking service endpoints..."
    
    # Test endpoints
    if curl -s "http://localhost:8000/api/health" >/dev/null 2>&1; then
        print_success "✅ Login Gateway health check passed"
    else
        print_error "❌ Login Gateway health check failed"
    fi
    
    if curl -s "http://localhost:8001/health" >/dev/null 2>&1; then
        print_success "✅ Auth Service health check passed"
    else
        print_error "❌ Auth Service health check failed"
    fi
    
    if curl -s "http://localhost:8002/health" >/dev/null 2>&1; then
        print_success "✅ Accounts Service health check passed"
    else
        print_error "❌ Accounts Service health check failed"
    fi
    
    if curl -s "http://localhost:8003/api/pdf/health" >/dev/null 2>&1; then
        print_success "✅ PDF Receipt Service health check passed"
    else
        print_error "❌ PDF Receipt Service health check failed"
    fi
    
    if curl -s "http://localhost:8005/core/health" >/dev/null 2>&1; then
        print_success "✅ CoreBanking Service health check passed"
    else
        print_error "❌ CoreBanking Service health check failed"
    fi

    if curl -s "http://localhost:8004/payments/health" >/dev/null 2>&1; then
        print_success "✅ Payment Service health check passed"
    else
        print_error "❌ Payment Service health check failed"
    fi

    if curl -s "http://localhost:5004/api/health" >/dev/null 2>&1; then
        print_success "✅ Payee Service health check passed"
    else
        print_error "❌ Payee Service health check failed"
    fi

    # Frontend health checks
    if curl -s "http://localhost:3000/health" >/dev/null 2>&1; then
        print_success "✅ React Frontend health check passed"
    else
        print_error "❌ React Frontend health check failed (not running)"
    fi
    
    if curl -s "http://localhost:8086/health" >/dev/null 2>&1; then
        print_success "✅ HTML Frontend health check passed"
    else
        print_error "❌ HTML Frontend health check failed (not running)"
    fi

    if curl -s "http://localhost:8086" >/dev/null 2>&1; then
        print_success "✅ Frontend Server health check passed"
    else
        print_error "❌ Frontend Server health check failed"
    fi
    
    echo ""
    check_status
}

# Display help
show_help() {
    print_header
    echo "VuNG Bank Service Management Script"
    echo ""
    echo "Usage: ./manage-services.sh [command]"
    echo ""
    echo "Commands:"
    echo "  status       - Check status of all services"
    echo "  start        - Start all services with HTML frontend container"
    echo "  stop         - Stop all services"
    echo "  restart      - Restart all services"
    echo "  install      - Install dependencies and setup"
    echo "  logs         - Show service logs"
    echo "  health       - Run health checks"
    echo "  configure    - Configure Kong Gateway services and routes"
    echo "  help         - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./manage-services.sh start                    # Start all services"
    echo "  ./manage-services.sh status                   # Check service status"
    echo "  ./manage-services.sh restart                  # Restart all services"
    echo "  ./manage-services.sh configure                # Re-configure Kong Gateway"
    echo ""
    echo "Services managed:"
    echo "  • PostgreSQL Database (port 5432)"
    echo "  • Go Login Gateway (port 8000)"
    echo "  • Python Auth Service (port 8001)"
    echo "  • Go Accounts Service (port 8002)"
    echo "  • Java PDF Receipt Service (port 8003)"
    echo "  • Java Payment Service (port 8004)"
    echo "  • Java CoreBanking Service (port 8005)"
    echo "  • .NET Payee Service (port 5004)"
    echo "  • HTML Frontend Container (port 8086)"
    echo "  • Kong API Gateway (port 8086)"
    echo ""
    echo "Enterprise Features:"
    echo "  ✅ Comprehensive APM monitoring with Elastic APM"
    echo "  ✅ Distributed tracing with correlation IDs"
    echo "  ✅ Request/Response logging with body capture"
    echo "  ✅ Rate limiting and security policies"
    echo "  ✅ CORS and security headers"
    echo "  ✅ Prometheus metrics collection"
    echo "  ✅ JWT authentication support"
    echo ""
    echo "APM Configuration:"
    echo "  🔗 APM Server: ${ELASTIC_APM_SERVER_URL}"
    echo "  🏷️  Environment: ${ELASTIC_APM_ENVIRONMENT}"
    echo "  📊 Sample Rate: ${ELASTIC_APM_TRANSACTION_SAMPLE_RATE}"
    echo "  📈 Tracing: ${ELASTIC_APM_USE_DISTRIBUTED_TRACING}"
    echo ""
}

# Main script logic
case "${1:-help}" in
    "status")
        check_status
        ;;
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        restart_services
        ;;
    "install")
        install_dependencies
        ;;
    "logs")
        show_logs
        ;;
    "health")
        health_check
        ;;
    "configure")
        print_header
        print_status "Manual Kong Gateway configuration..."
        configure_kong_services
        ;;
    "help"|"")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_help
        exit 1
        ;;
esac