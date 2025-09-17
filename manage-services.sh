#!/bin/bash

# VuNG Bank Service Management Script
# Usage: ./manage-services.sh [command]
# Commands: status, start, stop, restart, clean, install, logs, health

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
    echo "  VuNG Bank Service Management"
    echo "=========================================="
    echo ""
}

# Check if we're in the right directory
check_directory() {
    if [ ! -f "$PROJECT_DIR/docker-compose.yml" ]; then
        print_error "docker-compose.yml not found. Please run this script from the project root."
        exit 1
    fi
    cd "$PROJECT_DIR"
}

# Check service status
check_status() {
    print_header
    print_status "Checking service status..."
    echo ""
    
    echo "📋 Docker Services:"
    docker-compose ps 2>/dev/null || {
        print_warning "Docker services not running or docker-compose not available"
        echo ""
    }
    
    echo ""
    echo "🌐 Port Status:"
    
    # Check Docker services
    if lsof -i :5432 >/dev/null 2>&1; then
        print_success "✅ PostgreSQL Database (5432) - Running"
    else
        print_error "❌ PostgreSQL Database (5432) - Not Running"
    fi
    
    if lsof -i :8001 >/dev/null 2>&1; then
        print_success "✅ Python Auth Service (8001) - Running"
    else
        print_error "❌ Python Auth Service (8001) - Not Running"
    fi
    
    if lsof -i :8000 >/dev/null 2>&1; then
        print_success "✅ Go Login Service (8000) - Running"
    else
        print_error "❌ Go Login Service (8000) - Not Running"
    fi
    
    if lsof -i :8002 >/dev/null 2>&1; then
        print_success "✅ Go Accounts Service (8002) - Running"
    else
        print_error "❌ Go Accounts Service (8002) - Not Running"
    fi
    
    # Check Frontend
    if lsof -i :3001 >/dev/null 2>&1; then
        print_success "✅ React Frontend (3001) - Running"
    else
        print_error "❌ React Frontend (3001) - Not Running"
    fi
    
    echo ""
    echo "🔗 Service URLs:"
    echo "   Frontend:     http://localhost:3001"
    echo "   Login API:    http://localhost:8000"
    echo "   Auth Service: http://localhost:8001"
    echo "   Accounts API: http://localhost:8002"
    echo "   Database:     localhost:5432"
    echo ""
}

# Start all services
start_services() {
    print_header
    print_status "Starting all services..."
    echo ""
    
    # Start Docker services
    print_status "Starting Docker services..."
    docker-compose up -d
    
    # Wait for services to be healthy
    print_status "Waiting for services to be healthy..."
    sleep 10
    
    # Start frontend
    print_status "Starting React frontend..."
    
    # Kill any existing frontend process
    pkill -f "npm start" 2>/dev/null || true
    
    # Start frontend in background
    cd "$FRONTEND_DIR"
    PORT=$FRONTEND_PORT REACT_APP_API_URL=http://localhost:$BACKEND_API_PORT nohup npm start > frontend.log 2>&1 &
    FRONTEND_PID=$!
    echo $FRONTEND_PID > "$PROJECT_DIR/frontend.pid"
    
    print_status "Waiting for frontend to start..."
    sleep 15
    
    print_success "All services started!"
    check_status
}

# Stop all services
stop_services() {
    print_header
    print_status "Stopping all services..."
    echo ""
    
    # Stop frontend
    print_status "Stopping React frontend..."
    pkill -f "npm start" 2>/dev/null || true
    if [ -f "$PROJECT_DIR/frontend.pid" ]; then
        kill $(cat "$PROJECT_DIR/frontend.pid") 2>/dev/null || true
        rm -f "$PROJECT_DIR/frontend.pid"
    fi
    
    # Stop Docker services
    print_status "Stopping Docker services..."
    docker-compose down
    
    print_success "All services stopped!"
}

# Restart all services
restart_services() {
    print_header
    print_status "Restarting all services..."
    echo ""
    
    stop_services
    sleep 3
    start_services
}

# Clean up everything
clean_all() {
    print_header
    print_warning "This will remove all Docker images, containers, and volumes!"
    read -p "Are you sure you want to continue? (y/N): " -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Cleaning up..."
        
        # Stop everything first
        stop_services
        
        # Remove containers and networks
        print_status "Removing Docker containers and networks..."
        docker-compose down --volumes --remove-orphans 2>/dev/null || true
        
        # Remove project images
        print_status "Removing Docker images..."
        docker images --format "table {{.Repository}}:{{.Tag}}" | grep "vungbank" | awk '{print $1}' | xargs -r docker rmi -f 2>/dev/null || true
        
        # Clean up frontend
        print_status "Cleaning frontend build files..."
        rm -rf "$FRONTEND_DIR/node_modules/.cache" 2>/dev/null || true
        rm -f "$PROJECT_DIR/frontend.pid" 2>/dev/null || true
        rm -f "$FRONTEND_DIR/frontend.log" 2>/dev/null || true
        
        # Docker system cleanup
        print_status "Running Docker system cleanup..."
        docker system prune -f
        
        print_success "Cleanup completed!"
    else
        print_status "Cleanup cancelled."
    fi
}

# Fresh installation
install_fresh() {
    print_header
    print_status "Performing fresh installation..."
    echo ""
    
    # Clean first
    clean_all
    
    # Build and start
    print_status "Building Docker images..."
    docker-compose build --no-cache
    
    print_status "Starting services..."
    start_services
    
    print_success "Fresh installation completed!"
}

# Show logs
show_logs() {
    print_header
    print_status "Service Logs (last 20 lines each):"
    echo ""
    
    services=("vubank-postgres" "login-python-authenticator" "login-go-service" "accounts-go-service")
    
    for service in "${services[@]}"; do
        echo "📋 $service:"
        echo "----------------------------------------"
        docker logs "$service" --tail 20 2>/dev/null || print_warning "Service $service not running"
        echo ""
    done
    
    if [ -f "$FRONTEND_DIR/frontend.log" ]; then
        echo "📋 React Frontend:"
        echo "----------------------------------------"
        tail -20 "$FRONTEND_DIR/frontend.log"
        echo ""
    fi
}

# Health check
health_check() {
    print_header
    print_status "Performing health checks..."
    echo ""
    
    # Test database connection
    print_status "Testing database connection..."
    if docker exec vubank-postgres pg_isready -U vubank_user -d vubank_db >/dev/null 2>&1; then
        print_success "✅ Database is healthy"
    else
        print_error "❌ Database connection failed"
    fi
    
    # Test Go login service
    print_status "Testing Go login service..."
    if curl -s http://localhost:8000/api/health >/dev/null 2>&1; then
        print_success "✅ Go login service is healthy"
    else
        print_error "❌ Go login service not responding"
    fi
    
    # Test Python auth service
    print_status "Testing Python auth service..."
    if curl -s http://localhost:8001/health >/dev/null 2>&1; then
        print_success "✅ Python auth service is healthy"
    else
        print_error "❌ Python auth service not responding"
    fi
    
    # Test Go accounts service
    print_status "Testing Go accounts service..."
    if curl -s http://localhost:8002/health >/dev/null 2>&1; then
        print_success "✅ Go accounts service is healthy"
    else
        print_error "❌ Go accounts service not responding"
    fi
    
    # Test frontend
    print_status "Testing React frontend..."
    if curl -s http://localhost:3001 >/dev/null 2>&1; then
        print_success "✅ React frontend is healthy"
    else
        print_error "❌ React frontend not responding"
    fi
    
    echo ""
    print_status "🔑 Test Credentials:"
    echo "   Username: johndoe    | Password: password123"
    echo "   Username: janedoe    | Password: password123"
    echo "   Username: corpuser   | Password: password123"
    echo ""
}

# Show help
show_help() {
    print_header
    echo "Usage: ./manage-services.sh [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  status     Check status of all services"
    echo "  start      Start all services"
    echo "  stop       Stop all services"
    echo "  restart    Restart all services"
    echo "  clean      Clean up all Docker images and containers"
    echo "  install    Perform fresh installation"
    echo "  logs       Show service logs"
    echo "  health     Perform health checks"
    echo "  help       Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./manage-services.sh status"
    echo "  ./manage-services.sh restart"
    echo "  ./manage-services.sh clean"
    echo ""
}

# Main script logic
main() {
    check_directory
    
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
        "clean")
            clean_all
            ;;
        "install")
            install_fresh
            ;;
        "logs")
            show_logs
            ;;
        "health")
            health_check
            ;;
        "help"|"-h"|"--help")
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"