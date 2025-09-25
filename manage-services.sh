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
    echo "" output
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
    else
        print_error "❌ Kong API Gateway (8086) - Not Running"
    fi
    
    if docker compose --profile kong ps | grep -q "kong-postgres.*Up"; then
        print_success "✅ Kong Database (internal) - Running"
    else
        print_error "❌ Kong Database (internal) - Not Running"
    fi
    
    # Check individual services (internal ports only)
    if docker compose ps | grep -q "login-go-service.*Up"; then
        print_success "✅ Go Login Gateway (internal:8000) - Running"
    else
        print_error "❌ Go Login Gateway (internal:8000) - Not Running"
    fi
    
    if docker compose ps | grep -q "login-python-authenticator.*Up"; then
        print_success "✅ Python Auth Service (internal:8001) - Running"
    else
        print_error "❌ Python Auth Service (internal:8001) - Not Running"
    fi
    
    if docker compose ps | grep -q "accounts-go-service.*Up"; then
        print_success "✅ Go Accounts Service (internal:8002) - Running"
    else
        print_error "❌ Go Accounts Service (internal:8002) - Not Running"
    fi
    
    if docker compose ps | grep -q "pdf-receipt-java-service.*Up"; then
        print_success "✅ Java PDF Receipt Service (internal:8003) - Running"
    else
        print_error "❌ Java PDF Receipt Service (internal:8003) - Not Running"
    fi
    
    if docker compose ps | grep -q "corebanking-java-service.*Up"; then
        print_success "✅ Java CoreBanking Service (internal:8005) - Running"
    else
        print_error "❌ Java CoreBanking Service (internal:8005) - Not Running"
    fi

    if docker compose ps | grep -q "payment-process-java-service.*Up"; then
        print_success "✅ Java Payment Service (internal:8004) - Running"
    else
        print_error "❌ Java Payment Service (internal:8004) - Not Running"
    fi

    if docker compose ps | grep -q "payee-store-dotnet-service.*Up"; then
        print_success "✅ .NET Payee Service (internal:5004) - Running"
    else
        print_error "❌ .NET Payee Service (internal:5004) - Not Running"
    fi
    
    if docker compose ps | grep -q "vubank-postgres.*Up"; then
        print_success "✅ PostgreSQL Database (5432) - Running"
    else
        print_error "❌ PostgreSQL Database (5432) - Not Running"
    fi

    # Check HTML Frontend Container
    if docker compose --profile html-frontend ps | grep -q "vubank-html-frontend.*Up"; then
        print_success "✅ HTML Frontend (internal:80) - Running"
    else
        print_error "❌ HTML Frontend (internal:80) - Not Running"
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
    start_services "$1" "$2"
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

# Display help
show_help() {
    print_header
    echo "VuNG Bank Service Management Script"
    echo ""
    echo "Usage: ./manage-services.sh [command]"
    echo ""
    echo "Commands:"
    echo "  status    - Check status of all services"
    echo "  start     - Start all services with HTML frontend container"
    echo "  stop      - Stop all services"
    echo "  restart   - Restart all services"
    echo "  install   - Install dependencies and setup"
    echo "  uninstall - Complete removal of all services, containers, images and volumes"
    echo "  clean-cache - Clean Docker build cache and force fresh builds"
    echo "  logs      - Show service logs"
    echo "  health    - Run health checks"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./manage-services.sh start                    # Start all services"
    echo "  ./manage-services.sh status                   # Check service status"
    echo "  ./manage-services.sh restart                  # Restart all services"
    echo "  ./manage-services.sh uninstall                # Remove everything (containers, images, volumes)"
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
        check_status
        ;;
    "start")
        start_services
        ;;
    "stop")
        stop_services
        ;;
    "restart")
        restart_services "$1" "$2"
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
    "logs")
        show_logs
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