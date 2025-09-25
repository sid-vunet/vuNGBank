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
PROJECT_DIR="/Users/sidharthan/Documents/vuNGBank"
FRONTEND_DIR="$PROJECT_DIR/frontend"
KONG_GATEWAY_PORT=8086
KONG_ADMIN_PORT=8001
BACKEND_API_PORT=8000  # Now internal only

# Service definitions (using simple arrays for compatibility)
AVAILABLE_SERVICES="postgres kong-db kong-migrations kong login-python login-go accounts pdf payment corebanking payee frontend"

get_container_name() {
    case "$1" in
        "postgres") echo "vubank-postgres" ;;
        "kong-db") echo "kong-postgres" ;;
        "kong-migrations") echo "kong-migrations" ;;
        "kong") echo "vubank-kong-gateway" ;;
        "login-python") echo "login-python-authenticator" ;;
        "login-go") echo "login-go-service" ;;
        "accounts") echo "accounts-go-service" ;;
        "pdf") echo "pdf-receipt-java-service" ;;
        "payment") echo "payment-process-java-service" ;;
        "corebanking") echo "corebanking-java-service" ;;
        "payee") echo "payee-store-dotnet-service" ;;
        "frontend") echo "vubank-html-frontend" ;;
        *) echo "" ;;
    esac
}

get_service_profile() {
    case "$1" in
        "kong"|"kong-db"|"kong-migrations") echo "--profile kong" ;;
        "frontend") echo "--profile html-frontend" ;;
        *) echo "" ;;
    esac
}

# ============================================================================
# 📊 CENTRALIZED APM CONFIGURATION (Applied to ALL Services)
# ============================================================================
# Update these values to configure APM across all backend and frontend services

# APM Server Configuration
export ELASTIC_APM_SERVER_URL="${ELASTIC_APM_SERVER_URL:-http://91.203.133.240:30200}"
export ELASTIC_APM_ENVIRONMENT="${ELASTIC_APM_ENVIRONMENT:-dev-sid-mac}"
export ELASTIC_APM_SERVICE_VERSION="${ELASTIC_APM_SERVICE_VERSION:-1.0.0}"

# Sampling Configuration (100% for maximum observability)
export ELASTIC_APM_TRANSACTION_SAMPLE_RATE="${ELASTIC_APM_TRANSACTION_SAMPLE_RATE:-1.0}"
export ELASTIC_APM_SPAN_SAMPLE_RATE="${ELASTIC_APM_SPAN_SAMPLE_RATE:-1.0}"

# Data Capture Configuration (Maximum capture for all services)
export ELASTIC_APM_CAPTURE_BODY="${ELASTIC_APM_CAPTURE_BODY:-all}"
export ELASTIC_APM_CAPTURE_HEADERS="${ELASTIC_APM_CAPTURE_HEADERS:-true}"

# Distributed Tracing Configuration
export ELASTIC_APM_USE_DISTRIBUTED_TRACING="${ELASTIC_APM_USE_DISTRIBUTED_TRACING:-true}"

# Advanced Configuration for Maximum Observability
export ELASTIC_APM_LOG_LEVEL="${ELASTIC_APM_LOG_LEVEL:-info}"
export ELASTIC_APM_RECORDING="${ELASTIC_APM_RECORDING:-true}"
export ELASTIC_APM_STACK_TRACE_LIMIT="${ELASTIC_APM_STACK_TRACE_LIMIT:-50}"
export ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION="${ELASTIC_APM_SPAN_STACK_TRACE_MIN_DURATION:-0ms}"

# Performance Monitoring Settings
export ELASTIC_APM_DISABLE_METRICS="${ELASTIC_APM_DISABLE_METRICS:-false}"
export ELASTIC_APM_METRICS_INTERVAL="${ELASTIC_APM_METRICS_INTERVAL:-30s}"
export ELASTIC_APM_MAX_QUEUE_SIZE="${ELASTIC_APM_MAX_QUEUE_SIZE:-1000}"
export ELASTIC_APM_FLUSH_INTERVAL="${ELASTIC_APM_FLUSH_INTERVAL:-1s}"
export ELASTIC_APM_TRANSACTION_MAX_SPANS="${ELASTIC_APM_TRANSACTION_MAX_SPANS:-500}"

# Java-specific configuration
export ELASTIC_APM_SPAN_FRAMES_MIN_DURATION="${ELASTIC_APM_SPAN_FRAMES_MIN_DURATION:-0ms}"
export ELASTIC_APM_ENABLE_LOG_CORRELATION="${ELASTIC_APM_ENABLE_LOG_CORRELATION:-true}"
export ELASTIC_APM_PROFILING_INFERRED_SPANS_ENABLED="${ELASTIC_APM_PROFILING_INFERRED_SPANS_ENABLED:-true}"
export ELASTIC_APM_PROFILING_INFERRED_SPANS_MIN_DURATION="${ELASTIC_APM_PROFILING_INFERRED_SPANS_MIN_DURATION:-0ms}"
export ELASTIC_APM_INSTRUMENT="${ELASTIC_APM_INSTRUMENT:-true}"

# .NET-specific configuration  
export ELASTIC_APM_SERVER_URLS="${ELASTIC_APM_SERVER_URL}"

# Helper functions for service management
validate_service() {
    local service="$1"
    for s in $AVAILABLE_SERVICES; do
        if [[ "$s" == "$service" ]]; then
            return 0
        fi
    done
    return 1
}

list_available_services() {
    echo "Available services:"
    for service in $AVAILABLE_SERVICES; do
        local container=$(get_container_name "$service")
        echo "  • $service ($container)"
    done
}

print_apm_config() {
    echo ""
    echo "📊 Centralized APM Configuration:"
    echo "   Server URL: $ELASTIC_APM_SERVER_URL"
    echo "   Environment: $ELASTIC_APM_ENVIRONMENT" 
    echo "   Version: $ELASTIC_APM_SERVICE_VERSION"
    echo "   Sampling: ${ELASTIC_APM_TRANSACTION_SAMPLE_RATE}% transactions, ${ELASTIC_APM_SPAN_SAMPLE_RATE}% spans"
    echo "   Capture: Body=$ELASTIC_APM_CAPTURE_BODY, Headers=$ELASTIC_APM_CAPTURE_HEADERS"
    echo "   Distributed Tracing: $ELASTIC_APM_USE_DISTRIBUTED_TRACING"
    echo "   Log Level: $ELASTIC_APM_LOG_LEVEL"
    echo ""
}
# ============================================================================

#     echo "Services managed:"
    echo "  🌐 Kong API Gateway (port 8086) - MAIN ENTRY POINT"
    echo "  🔧 Kong Admin API (port 8001)"
    echo "  🎛️  Kong Admin GUI (port 8002)"
    echo "  🗄️  PostgreSQL Database (port 5432)"
    echo "  🗄️  Kong PostgreSQL Database (internal)"
    echo ""
    echo "Backend Services (internal access only via Kong):"
    echo "  • Go Login Gateway (internal:8000)"
    echo "  • Python Auth Service (internal:8001)"
    echo "  • Go Accounts Service (internal:8002)"
    echo "  • Java PDF Receipt Service (internal:8003)"
    echo "  • Java Payment Service (internal:8004)"
    echo "  • Java CoreBanking Service (internal:8005)"
    echo "  • .NET Payee Service (internal:5004)"
    echo "  • HTML Frontend Container (internal:80)"
    echo ""
    echo "Enterprise Features:"
    echo "  ✅ Comprehensive APM monitoring with Elastic APM"
    echo "  ✅ Distributed tracing with correlation IDs"
    echo "  ✅ Request/Response logging with body capture"
    echo "  ✅ Rate limiting and security policies"
    echo "  ✅ CORS and security headers"
    echo "  ✅ Prometheus metrics collection"
    echo "  ✅ JWT authentication support"
    print_apm_config output
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
    echo "        With Kong API Gateway (8086)"
    echo "=========================================="
    echo ""
}

# Check service status (all or specific)
check_status() {
    local services=("$@")
    
    print_header
    if [ ${#services[@]} -eq 0 ]; then
        echo "🔍 Service Status Check (All Services):"
    else
        echo "🔍 Service Status Check (${services[*]}):"
        
        # Validate all services first
        for service in "${services[@]}"; do
            if ! validate_service "$service"; then
                print_error "Unknown service: $service"
                echo ""
                list_available_services
                exit 1
            fi
        done
    fi
    echo ""
    
    # Check Docker services
    if ! docker compose ps >/dev/null 2>&1; then
        print_error "❌ Docker Compose not available"
        return 1
    fi
    
    # Function to check if service should be displayed
    should_check_service() {
        local service="$1"
        if [ ${#services[@]} -eq 0 ]; then
            return 0  # Check all services
        fi
        for s in "${services[@]}"; do
            if [[ "$s" == "$service" ]]; then
                return 0
            fi
        done
        return 1
    }
    
    # Check Kong API Gateway first
    if should_check_service "kong"; then
        if docker compose --profile kong ps | grep -q "vubank-kong-gateway.*Up"; then
            print_success "✅ Kong API Gateway (8086) - Running"
        else
            print_error "❌ Kong API Gateway (8086) - Not Running"
        fi
    fi
    
    if should_check_service "kong-db"; then
        if docker compose --profile kong ps | grep -q "kong-postgres.*Up"; then
            print_success "✅ Kong Database (internal) - Running"
        else
            print_error "❌ Kong Database (internal) - Not Running"
        fi
    fi
    
    # Check individual services (internal ports only)
    if should_check_service "login-go"; then
        if docker compose ps | grep -q "login-go-service.*Up"; then
            print_success "✅ Go Login Gateway (internal:8000) - Running"
        else
            print_error "❌ Go Login Gateway (internal:8000) - Not Running"
        fi
    fi
    
    if should_check_service "login-python"; then
        if docker compose ps | grep -q "login-python-authenticator.*Up"; then
            print_success "✅ Python Auth Service (internal:8001) - Running"
        else
            print_error "❌ Python Auth Service (internal:8001) - Not Running"
        fi
    fi
    
    if should_check_service "accounts"; then
        if docker compose ps | grep -q "accounts-go-service.*Up"; then
            print_success "✅ Go Accounts Service (internal:8002) - Running"
        else
            print_error "❌ Go Accounts Service (internal:8002) - Not Running"
        fi
    fi
    
    if should_check_service "pdf"; then
        if docker compose ps | grep -q "pdf-receipt-java-service.*Up"; then
            print_success "✅ Java PDF Receipt Service (internal:8003) - Running"
        else
            print_error "❌ Java PDF Receipt Service (internal:8003) - Not Running"
        fi
    fi
    
    if should_check_service "corebanking"; then
        if docker compose ps | grep -q "corebanking-java-service.*Up"; then
            print_success "✅ Java CoreBanking Service (internal:8005) - Running"
        else
            print_error "❌ Java CoreBanking Service (internal:8005) - Not Running"
        fi
    fi

    if should_check_service "payment"; then
        if docker compose ps | grep -q "payment-process-java-service.*Up"; then
            print_success "✅ Java Payment Service (internal:8004) - Running"
        else
            print_error "❌ Java Payment Service (internal:8004) - Not Running"
        fi
    fi

    if should_check_service "payee"; then
        if docker compose ps | grep -q "payee-store-dotnet-service.*Up"; then
            print_success "✅ .NET Payee Service (internal:5004) - Running"
        else
            print_error "❌ .NET Payee Service (internal:5004) - Not Running"
        fi
    fi
    
    if should_check_service "postgres"; then
        if docker compose ps | grep -q "vubank-postgres.*Up"; then
            print_success "✅ PostgreSQL Database (5432) - Running"
        else
            print_error "❌ PostgreSQL Database (5432) - Not Running"
        fi
    fi

    # Check HTML Frontend Container
    if should_check_service "frontend"; then
        if docker compose --profile html-frontend ps | grep -q "vubank-html-frontend.*Up"; then
            print_success "✅ HTML Frontend (internal:80) - Running"
        else
            print_error "❌ HTML Frontend (internal:80) - Not Running"
        fi
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
    echo "     • Session API:    http://localhost:8086/api/session"
    echo "     • Accounts API:   http://localhost:8086/accounts"
    echo "     • Payments API:   http://localhost:8086/payments"
    echo "     • PDF API:        http://localhost:8086/api/pdf"
    echo "     • Payees API:     http://localhost:8086/api/payees"
    echo "     • CoreBanking:    http://localhost:8086/core"
    echo ""
    echo "   Management:"
    echo "     • Kong Admin API: http://localhost:8001"
    echo "     • Kong Admin GUI: http://localhost:8002"
    echo "     • Database:       localhost:5432"
    echo ""
}

# Start services (all or specific)
start_services() {
    local services=("${@:1}")  # Get all arguments as services
    
    print_header
    if [ ${#services[@]} -eq 0 ]; then
        print_status "Starting all services..."
    else
        print_status "Starting specific services: ${services[*]}..."
        # Validate all services first
        for service in "${services[@]}"; do
            if ! validate_service "$service"; then
                print_error "Unknown service: $service"
                echo ""
                list_available_services
                exit 1
            fi
        done
    fi
    echo ""
    
    # Start services
    start_services_with_container "${services[@]}"
}

# Start services with container support
start_services_with_container() {
    local services=("$@")
    local compose_cmd
    
    if [ ${#services[@]} -eq 0 ]; then
        # Start all services
        print_status "Starting all services with Kong API Gateway and HTML frontend container..."
        
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
        
        # Wait for Kong to be ready and configure it automatically
        print_status "Waiting for Kong API Gateway to be ready..."
        sleep 15
        
        # Auto-configure Kong services and routes
        print_status "Configuring Kong Gateway services and routes..."
        if [ -f "kong/configure-kong-auto.sh" ]; then
            ./kong/configure-kong-auto.sh
        else
            print_error "Kong configuration script not found!"
        fi
        
        print_success "All services started with Kong API Gateway (port 8086) and HTML frontend!"
    else
        # Start specific services
        local need_kong=false
        local need_frontend=false
        local need_kong_deps=false
        
        # Check if we need Kong or frontend
        for service in "${services[@]}"; do
            if [[ "$service" == "kong" ]]; then
                need_kong=true
                need_kong_deps=true
            elif [[ "$service" == "frontend" ]]; then
                need_frontend=true
            elif [[ "$service" != "kong-db" && "$service" != "kong-migrations" && "$service" != "postgres" ]]; then
                # Most services need Kong to be accessible
                need_kong_deps=true
            fi
        done
        
        # Start Kong dependencies if needed
        if [[ "$need_kong_deps" == "true" ]]; then
            print_status "Starting Kong dependencies (database and migrations)..."
            docker compose --profile kong up kong-postgres kong-migrations -d --build
            sleep 10
        fi
        
        # Build frontend if needed
        if [[ "$need_frontend" == "true" ]]; then
            print_status "Building HTML frontend container..."
            cd frontend && chmod +x build-html-container.sh && ./build-html-container.sh && cd ..
        fi
        
        # Build compose command for specific services
        local profiles=""
        local container_names=""
        
        # Collect unique profiles
        for service in "${services[@]}"; do
            local profile=$(get_service_profile "$service")
            if [[ -n "$profile" ]] && [[ ! "$profiles" =~ "$profile" ]]; then
                if [[ -n "$profiles" ]]; then
                    profiles="$profiles $profile"
                else
                    profiles="$profile"
                fi
            fi
        done
        
        # Collect container names
        for service in "${services[@]}"; do
            local container=$(get_container_name "$service")
            if [[ -n "$container_names" ]]; then
                container_names="$container_names $container"
            else
                container_names="$container"
            fi
        done
        
        print_status "Starting services: ${services[*]}..."
        if [[ -n "$profiles" ]]; then
            docker compose $profiles up -d --build $container_names
        else
            docker compose up -d --build $container_names
        fi
        
        # Configure Kong if it was started
        if [[ "$need_kong" == "true" ]]; then
            print_status "Waiting for Kong API Gateway to be ready..."
            sleep 15
            print_status "Configuring Kong Gateway services and routes..."
            if [ -f "kong/configure-kong-auto.sh" ]; then
                ./kong/configure-kong-auto.sh
            else
                print_error "Kong configuration script not found!"
            fi
        fi
        
        print_success "Services started: ${services[*]}!"
    fi
    
    echo ""
    print_status "🔗 Access your application at: http://localhost:8086"
    print_apm_config
    check_status
}

# Start services with React container  
# Stop services (all or specific)
stop_services() {
    local services=("$@")
    
    print_header
    if [ ${#services[@]} -eq 0 ]; then
        print_status "Stopping all services..."
        echo ""
        
        # Stop Docker services (including Kong and HTML frontend containers)
        print_status "Stopping Docker services with Kong API Gateway..."
        docker compose --profile kong --profile html-frontend --profile frontend down --remove-orphans
        
        print_success "All services stopped!"
    else
        print_status "Stopping specific services: ${services[*]}..."
        echo ""
        
        # Validate all services first
        for service in "${services[@]}"; do
            if ! validate_service "$service"; then
                print_error "Unknown service: $service"
                echo ""
                list_available_services
                exit 1
            fi
        done
        
        # Stop specific services
        local profiles=""
        local container_names=""
        
        # Collect unique profiles
        for service in "${services[@]}"; do
            local profile=$(get_service_profile "$service")
            if [[ -n "$profile" ]] && [[ ! "$profiles" =~ "$profile" ]]; then
                if [[ -n "$profiles" ]]; then
                    profiles="$profiles $profile"
                else
                    profiles="$profile"
                fi
            fi
        done
        
        # Collect container names
        for service in "${services[@]}"; do
            local container=$(get_container_name "$service")
            if [[ -n "$container_names" ]]; then
                container_names="$container_names $container"
            else
                container_names="$container"
            fi
        done
        
        print_status "Stopping services..."
        if [[ -n "$profiles" ]]; then
            docker compose $profiles stop $container_names
        else
            docker compose stop $container_names
        fi
        
        print_success "Services stopped: ${services[*]}!"
    fi
}

# Restart services (all or specific)
restart_services() {
    local services=("$@")
    
    print_header
    if [ ${#services[@]} -eq 0 ]; then
        print_status "Restarting all services..."
    else
        print_status "Restarting specific services: ${services[*]}..."
    fi
    echo ""
    
    stop_services "${services[@]}"
    sleep 5
    start_services "${services[@]}"
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

# Show logs (all or specific services)
show_logs() {
    local services=("$@")
    
    print_header
    if [ ${#services[@]} -eq 0 ]; then
        echo "📋 Service Logs (All Services):"
        echo ""
        echo "Docker Services:"
        docker compose logs --tail=50
        echo ""
        echo "Frontend Server:"
        ./frontend-server.sh logs
    else
        echo "📋 Service Logs (${services[*]}):"
        echo ""
        
        # Validate all services first
        for service in "${services[@]}"; do
            if ! validate_service "$service"; then
                print_error "Unknown service: $service"
                echo ""
                list_available_services
                exit 1
            fi
        done
        
        # Show logs for specific services
        for service in "${services[@]}"; do
            local container=$(get_container_name "$service")
            echo "--- Logs for $service ($container) ---"
            docker compose logs --tail=50 "$container"
            echo ""
        done
    fi
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
    print_status "Checking service endpoints through Kong API Gateway..."
    
    # Test Kong API Gateway health
    if curl -s "http://localhost:8086" >/dev/null 2>&1; then
        print_success "✅ Kong API Gateway health check passed"
    else
        print_error "❌ Kong API Gateway health check failed"
    fi
    
    # Test Kong Admin API
    if curl -s "http://localhost:8001" >/dev/null 2>&1; then
        print_success "✅ Kong Admin API health check passed"
    else
        print_error "❌ Kong Admin API health check failed"
    fi
    
    # Test endpoints through Kong Gateway (port 8086)
    if curl -s "http://localhost:8086/api/health" >/dev/null 2>&1; then
        print_success "✅ Login Gateway (via Kong) health check passed"
    else
        print_error "❌ Login Gateway (via Kong) health check failed"
    fi
    
    if curl -s "http://localhost:8086/health" >/dev/null 2>&1; then
        print_success "✅ Auth Service (via Kong) health check passed"
    else
        print_error "❌ Auth Service (via Kong) health check failed"
    fi
    
    if curl -s "http://localhost:8086/accounts" >/dev/null 2>&1; then
        print_success "✅ Accounts Service (via Kong) health check passed"
    else
        print_error "❌ Accounts Service (via Kong) health check failed"
    fi
    
    if curl -s "http://localhost:8086/api/pdf/health" >/dev/null 2>&1; then
        print_success "✅ PDF Receipt Service (via Kong) health check passed"
    else
        print_error "❌ PDF Receipt Service (via Kong) health check failed"
    fi
    
    if curl -s "http://localhost:8086/core/health" >/dev/null 2>&1; then
        print_success "✅ CoreBanking Service (via Kong) health check passed"
    else
        print_error "❌ CoreBanking Service (via Kong) health check failed"
    fi

    if curl -s "http://localhost:8086/payments/health" >/dev/null 2>&1; then
        print_success "✅ Payment Service (via Kong) health check passed"
    else
        print_error "❌ Payment Service (via Kong) health check failed"
    fi

    if curl -s "http://localhost:8086/api/payees" >/dev/null 2>&1; then
        print_success "✅ Payee Service (via Kong) health check passed"
    else
        print_error "❌ Payee Service (via Kong) health check failed"
    fi

    # Frontend health checks through Kong
    if curl -s "http://localhost:8086/login.html" >/dev/null 2>&1; then
        print_success "✅ HTML Frontend (via Kong) health check passed"
    else
        print_error "❌ HTML Frontend (via Kong) health check failed"
    fi
    
    echo ""
    check_status
}

# Complete uninstall - remove all containers, images, volumes and networks
uninstall_services() {
    print_header
    print_warning "⚠️  WARNING: This will completely remove all VuNG Bank services, containers, images, volumes and data!"
    print_warning "⚠️  This includes base Docker images: Kong (3.8.0) and Postgres (15)"
    print_warning "⚠️  This action cannot be undone and all data will be lost!"
    echo ""
    
    read -p "Are you sure you want to proceed? Type 'YES' to continue: " confirmation
    if [ "$confirmation" != "YES" ]; then
        print_status "Uninstall cancelled."
        return 0
    fi
    
    echo ""
    print_status "🧹 Starting complete cleanup..."
    echo ""
    
    # Step 1: Stop all running services
    print_status "1️⃣ Stopping all services..."
    docker compose --profile kong --profile html-frontend --profile frontend down --remove-orphans 2>/dev/null || true
    
    # Step 2: Remove all VuNG Bank containers (running and stopped)
    print_status "2️⃣ Removing all VuNG Bank containers..."
    docker ps -a --filter "name=vubank" --format "{{.Names}}" | while read container; do
        if [ -n "$container" ]; then
            print_status "   Removing container: $container"
            docker rm -f "$container" 2>/dev/null || true
        fi
    done
    
    # Remove service-specific containers
    for service in "login-python-authenticator" "login-go-service" "accounts-go-service" "pdf-receipt-java-service" "payment-process-java-service" "corebanking-java-service" "payee-store-dotnet-service" "kong-postgres" "kong-migrations" "vubank-kong-gateway"; do
        if docker ps -a --format "{{.Names}}" | grep -q "^${service}$"; then
            print_status "   Removing container: $service"
            docker rm -f "$service" 2>/dev/null || true
        fi
    done
    
    # Step 3: Remove all VuNG Bank images
    print_status "3️⃣ Removing all VuNG Bank Docker images..."
    
    # Remove images by repository pattern
    docker images --format "{{.Repository}}:{{.Tag}}" | grep -E "(vubank|vungbank)" | while read image; do
        if [ -n "$image" ]; then
            print_status "   Removing image: $image"
            docker rmi -f "$image" 2>/dev/null || true
        fi
    done
    
    # Remove service-specific images by service directory names
    for service_dir in "login-python-authenticator" "login-go-service" "accounts-go-service" "pdf-receipt-java-service" "payment-process-java-service" "corebanking-java-service" "payee-store-dotnet-service" "frontend"; do
        service_image="${PROJECT_DIR##*/}_${service_dir}"
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "$service_image"; then
            print_status "   Removing image: $service_image"
            docker rmi -f "$service_image" 2>/dev/null || true
        fi
    done
    
    # Remove base images used by VuBank services (Kong and Postgres)
    print_status "   Removing base Kong and Postgres images used by VuBank..."
    for base_image in "kong:3.8.0" "postgres:15"; do
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${base_image}$"; then
            print_status "   Removing base image: $base_image"
            docker rmi -f "$base_image" 2>/dev/null || true
        fi
    done
    
    # Step 4: Remove all volumes
    print_status "4️⃣ Removing all VuNG Bank volumes..."
    docker volume ls --format "{{.Name}}" | grep -E "(vubank|vungbank|postgres_data|kong_postgres_data|kong_logs|redis_data)" | while read volume; do
        if [ -n "$volume" ]; then
            print_status "   Removing volume: $volume"
            docker volume rm -f "$volume" 2>/dev/null || true
        fi
    done
    
    # Remove project-specific volumes
    project_name="${PROJECT_DIR##*/}"
    docker volume ls --format "{{.Name}}" | grep "^${project_name}_" | while read volume; do
        if [ -n "$volume" ]; then
            print_status "   Removing volume: $volume"
            docker volume rm -f "$volume" 2>/dev/null || true
        fi
    done
    
    # Step 5: Remove networks
    print_status "5️⃣ Removing VuNG Bank networks..."
    docker network ls --format "{{.Name}}" | grep -E "(vubank|vungbank)" | while read network; do
        if [ -n "$network" ] && [ "$network" != "bridge" ] && [ "$network" != "host" ] && [ "$network" != "none" ]; then
            print_status "   Removing network: $network"
            docker network rm "$network" 2>/dev/null || true
        fi
    done
    
    # Remove project-specific network
    project_network="${project_name}_vubank-network"
    if docker network ls --format "{{.Name}}" | grep -q "^${project_network}$"; then
        print_status "   Removing network: $project_network"
        docker network rm "$project_network" 2>/dev/null || true
    fi
    
    # Step 6: Clean up dangling images and build cache
    print_status "6️⃣ Cleaning up Docker system..."
    docker system prune -f 2>/dev/null || true
    
    # Step 7: Remove any remaining orphaned containers
    print_status "7️⃣ Final cleanup - removing any orphaned containers..."
    docker container prune -f 2>/dev/null || true
    
    echo ""
    print_success "✅ Complete uninstall finished!"
    print_success "🎯 All VuNG Bank services, containers, images, volumes and networks have been removed."
    print_status "💡 You can run './manage-services.sh install' to set up the services again."
    echo ""
    
    # Show remaining Docker resources for verification
    print_status "📋 Remaining Docker resources summary:"
    echo "   Containers: $(docker ps -a | wc -l) total"
    echo "   Images: $(docker images | wc -l) total"
    echo "   Volumes: $(docker volume ls | wc -l) total"
    echo "   Networks: $(docker network ls | wc -l) total"
    echo ""
}

# Build services (all or specific)
build_services() {
    local services=("$@")
    
    print_header
    if [ ${#services[@]} -eq 0 ]; then
        print_status "Building all services..."
        echo ""
        
        # Build HTML frontend container
        print_status "Building HTML frontend container..."
        cd frontend && chmod +x build-html-container.sh && ./build-html-container.sh && cd ..
        
        # Build all services
        print_status "Building all Docker services..."
        docker compose --profile kong --profile html-frontend build --no-cache
        
        print_success "All services built successfully!"
    else
        print_status "Building specific services: ${services[*]}..."
        echo ""
        
        # Validate all services first
        for service in "${services[@]}"; do
            if ! validate_service "$service"; then
                print_error "Unknown service: $service"
                echo ""
                list_available_services
                exit 1
            fi
        done
        
        # Build frontend if needed
        for service in "${services[@]}"; do
            if [[ "$service" == "frontend" ]]; then
                print_status "Building HTML frontend container..."
                cd frontend && chmod +x build-html-container.sh && ./build-html-container.sh && cd ..
                break
            fi
        done
        
        # Build specific services
        local profiles=""
        local container_names=""
        
        # Collect unique profiles
        for service in "${services[@]}"; do
            local profile=$(get_service_profile "$service")
            if [[ -n "$profile" ]] && [[ ! "$profiles" =~ "$profile" ]]; then
                if [[ -n "$profiles" ]]; then
                    profiles="$profiles $profile"
                else
                    profiles="$profile"
                fi
            fi
        done
        
        # Collect container names
        for service in "${services[@]}"; do
            local container=$(get_container_name "$service")
            if [[ -n "$container_names" ]]; then
                container_names="$container_names $container"
            else
                container_names="$container"
            fi
        done
        
        print_status "Building services..."
        if [[ -n "$profiles" ]]; then
            docker compose $profiles build --no-cache $container_names
        else
            docker compose build --no-cache $container_names
        fi
        
        print_success "Services built: ${services[*]}!"
    fi
}

# Clean Docker build cache and force fresh builds
clean_cache() {
    print_header
    print_status "Cleaning Docker build cache for fresh builds..."
    echo ""
    
    # Step 1: Stop all running containers first
    print_status "1️⃣ Stopping all running VuNG Bank containers..."
    docker compose --profile kong --profile html-frontend --profile frontend down --remove-orphans 2>/dev/null || true
    
    # Step 2: Clean Docker build cache
    print_status "2️⃣ Cleaning Docker build cache..."
    docker builder prune -a -f 2>/dev/null || true
    
    # Step 3: Remove VuNG Bank images to force rebuild
    print_status "3️⃣ Removing VuNG Bank images to force fresh rebuild..."
    docker images | grep -E "(vubank|vungbank)" | awk '{print $3}' | while read image_id; do
        if [ -n "$image_id" ] && [ "$image_id" != "IMAGE" ]; then
            print_status "   Removing image: $image_id"
            docker rmi -f "$image_id" 2>/dev/null || true
        fi
    done
    
    # Step 4: Clean unused Docker resources
    print_status "4️⃣ Cleaning unused Docker resources..."
    docker system prune -f 2>/dev/null || true
    
    echo ""
    print_success "✅ Docker build cache cleaned successfully!"
    print_status "💡 Next start/restart will build everything fresh from scratch."
    echo ""
    
    # Show cache usage before and after
    print_status "📊 Current Docker system usage:"
    docker system df 2>/dev/null || echo "Docker system df not available"
    echo ""
}

# Show APM configuration
show_apm_config() {
    print_header
    echo "📊 Centralized APM Configuration for All Services"
    echo ""
    echo "Current Configuration:"
    print_apm_config
    echo "This configuration is automatically applied to:"
    echo "  • All 7 backend services (Go, Python, .NET, Java)"
    echo "  • Frontend RUM agent"
    echo "  • Kong API Gateway logging"
    echo ""
    echo "To modify these values:"
    echo "  1. Edit the environment variables in this script (manage-services.sh)"
    echo "  2. Or set them as system environment variables"
    echo "  3. Restart services to apply changes: ./manage-services.sh restart"
    echo ""
    echo "Key Configuration Variables:"
    echo "  ELASTIC_APM_SERVER_URL - APM server endpoint"
    echo "  ELASTIC_APM_ENVIRONMENT - Environment (production/staging/dev)"
    echo "  ELASTIC_APM_TRANSACTION_SAMPLE_RATE - Transaction sampling (0.0-1.0)"
    echo "  ELASTIC_APM_CAPTURE_BODY - Body capture (all/errors/transactions/off)"
    echo "  ELASTIC_APM_CAPTURE_HEADERS - Header capture (true/false)"
    echo ""
}

# Display help
show_help() {
    print_header
    echo "VuNG Bank Service Management Script"
    echo ""
    echo "Usage: ./manage-services.sh [command] [service1] [service2] ..."
    echo ""
    echo "Commands:"
    echo "  status [services]   - Check status of all or specific services"
    echo "  start [services]    - Start all or specific services"
    echo "  stop [services]     - Stop all or specific services"
    echo "  restart [services]  - Restart all or specific services"
    echo "  build [services]    - Build all or specific services"
    echo "  logs [services]     - Show logs for all or specific services"
    echo "  install             - Install dependencies and setup"
    echo "  uninstall           - Complete removal: services, containers, images (including Kong/Postgres), volumes"
    echo "  clean-cache         - Clean Docker build cache and force fresh builds"
    echo "  apm-config          - Show centralized APM configuration for all services"
    echo "  health              - Run health checks"
    echo "  help                - Show this help message"
    echo ""
    echo "Available Services:"
    for service in $AVAILABLE_SERVICES; do
        local container=$(get_container_name "$service")
        printf "  %-15s - %s\n" "$service" "$container"
    done
    echo ""
    echo "Examples:"
    echo "  ./manage-services.sh start                    # Start all services"
    echo "  ./manage-services.sh start kong postgres      # Start only Kong and PostgreSQL"
    echo "  ./manage-services.sh stop login-python        # Stop only Python authenticator"
    echo "  ./manage-services.sh restart accounts payee   # Restart accounts and payee services"
    echo "  ./manage-services.sh build login-go payment   # Build only Go login and payment services"
    echo "  ./manage-services.sh logs kong                # Show logs for Kong only"
    echo "  ./manage-services.sh status                   # Check all services status"
    echo "  ./manage-services.sh uninstall                # Remove everything (including Kong/Postgres base images)"
    echo "  ./manage-services.sh clean-cache              # Clean Docker cache for fresh builds"
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
    echo "  • HTML Frontend Container (port 3001)"
    echo ""
    echo "Note: Redis has been removed as it's not currently needed by the services."
    echo ""
}

# Main script logic
case "${1:-help}" in
    "status")
        check_status "${@:2}"
        ;;
    "start")
        start_services "${@:2}"
        ;;
    "stop")
        stop_services "${@:2}"
        ;;
    "restart")
        restart_services "${@:2}"
        ;;
    "build")
        build_services "${@:2}"
        ;;
    "install")
        install_dependencies
        ;;
    "uninstall")
        uninstall_services
        ;;
    "clean-cache")
        clean_cache
        ;;
    "apm-config")
        show_apm_config
        ;;
    "logs")
        show_logs "${@:2}"
        ;;
    "health")
        health_check
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