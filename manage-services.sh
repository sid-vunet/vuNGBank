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
FRONTEND_PORT=3001
BACKEND_API_PORT=8000

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
    if docker compose ps | grep -q "vubank-html-frontend.*Up"; then
        print_success "✅ HTML Frontend (3001) - Running"
    else
        print_error "❌ HTML Frontend (3001) - Not Running"
    fi
    
    echo ""
    echo "🔗 Service URLs:"
    echo "   HTML Frontend:    http://localhost:3001"
    echo "   Login API:        http://localhost:8000"
    echo "   Auth Service:     http://localhost:8001"
    echo "   Accounts API:     http://localhost:8002"
    echo "   PDF Service:      http://localhost:8003"
    echo "   Payment Service:  http://localhost:8004 (with health: /payments/health)"
    echo "   Payee Service:    http://localhost:5004 (with health: /api/health)"
    echo "   CoreBanking:      http://localhost:8005"
    echo "   Database:         localhost:5432"
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
    print_status "Starting services with HTML frontend container..."
    
    # Build HTML container if needed
    print_status "Building HTML frontend container..."
    cd frontend && chmod +x build-html-container.sh && ./build-html-container.sh && cd ..
    
    # Start Docker services with HTML frontend profile
    print_status "Starting Docker services with HTML frontend..."
    docker compose --profile html-frontend up -d
    
    print_success "All services started with HTML frontend container!"
    check_status
}

# Start services with React container  
# Stop all services
stop_services() {
    print_header
    print_status "Stopping all services..."
    echo ""
    
    # Stop Docker services (including HTML frontend container)
    print_status "Stopping Docker services..."
    docker compose --profile html-frontend down
    
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
    
    if curl -s "http://localhost:3001/health" >/dev/null 2>&1; then
        print_success "✅ HTML Frontend health check passed"
    else
        print_error "❌ HTML Frontend health check failed (not running)"
    fi

    if curl -s "http://localhost:3001" >/dev/null 2>&1; then
        print_success "✅ Frontend Server health check passed"
    else
        print_error "❌ Frontend Server health check failed"
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
    docker compose --profile html-frontend --profile frontend down --remove-orphans 2>/dev/null || true
    
    # Step 2: Remove all VuNG Bank containers (running and stopped)
    print_status "2️⃣ Removing all VuNG Bank containers..."
    docker ps -a --filter "name=vubank" --format "{{.Names}}" | while read container; do
        if [ -n "$container" ]; then
            print_status "   Removing container: $container"
            docker rm -f "$container" 2>/dev/null || true
        fi
    done
    
    # Remove service-specific containers
    for service in "login-python-authenticator" "login-go-service" "accounts-go-service" "pdf-receipt-java-service" "payment-process-java-service" "corebanking-java-service" "payee-store-dotnet-service"; do
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
    docker volume ls --format "{{.Name}}" | grep -E "(vubank|vungbank|postgres_data|redis_data)" | while read volume; do
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
    echo "  logs      - Show service logs"
    echo "  health    - Run health checks"
    echo "  help      - Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./manage-services.sh start                    # Start all services"
    echo "  ./manage-services.sh status                   # Check service status"
    echo "  ./manage-services.sh restart                  # Restart all services"
    echo "  ./manage-services.sh uninstall                # Remove everything (containers, images, volumes)"
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