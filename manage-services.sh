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
    
    if docker compose ps | grep -q "vubank-postgres.*Up"; then
        print_success "✅ PostgreSQL Database (5432) - Running"
    else
        print_error "❌ PostgreSQL Database (5432) - Not Running"
    fi
    
    # Check Frontend (HTML Server)
    if lsof -i :$FRONTEND_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_success "✅ HTML Frontend Server (3001) - Running"
    else
        print_error "❌ HTML Frontend Server (3001) - Not Running"
    fi
    
    echo ""
    echo "🔗 Service URLs:"
    echo "   Frontend:     http://localhost:3001"
    echo "   Login API:    http://localhost:8000"
    echo "   Auth Service: http://localhost:8001"
    echo "   Accounts API: http://localhost:8002"
    echo "   PDF Service:  http://localhost:8003"
    echo "   Database:     localhost:5432"
    echo ""
}

# Start all services
start_services() {
    print_header
    print_status "Starting all services..."
    echo ""
    
    # Clean up any existing processes on port 3001 before starting
    if lsof -i :3001 >/dev/null 2>&1; then
        print_status "Cleaning up existing processes on port 3001..."
        lsof -ti :3001 | xargs kill -9 2>/dev/null || true
        sleep 2
    fi
    
    # Start Docker services
    print_status "Starting Docker services..."
    docker compose up -d
    
    # Wait for services to be healthy
    print_status "Waiting for services to be healthy..."
    sleep 10
    
    # Start frontend
    print_status "Starting HTML frontend server..."
    ./frontend-server.sh start
    
    print_success "All services started!"
    check_status
}

# Stop all services
stop_services() {
    print_header
    print_status "Stopping all services..."
    echo ""
    
    # Stop frontend
    print_status "Stopping HTML frontend server..."
    ./frontend-server.sh stop
    
    # Kill any remaining React or other frontend processes on port 3001
    print_status "Cleaning up any remaining frontend processes..."
    if lsof -i :3001 >/dev/null 2>&1; then
        print_status "Found processes using port 3001, terminating them..."
        lsof -ti :3001 | xargs kill -9 2>/dev/null || true
    fi
    
    # Stop Docker services
    print_status "Stopping Docker services..."
    docker compose down
    
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
    if curl -s "http://localhost:8000/health" >/dev/null 2>&1; then
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
    
    if curl -s "http://localhost:3001" >/dev/null 2>&1; then
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
    echo "  status    - Check status of all services"
    echo "  start     - Start all services"
    echo "  stop      - Stop all services"
    echo "  restart   - Restart all services"
    echo "  install   - Install dependencies and setup"
    echo "  logs      - Show service logs"
    echo "  health    - Run health checks"
    echo "  help      - Show this help message"
    echo ""
    echo "Services managed:"
    echo "  • PostgreSQL Database (port 5432)"
    echo "  • Go Login Gateway (port 8000)"
    echo "  • Python Auth Service (port 8001)"
    echo "  • Go Accounts Service (port 8002)"
    echo "  • Java PDF Receipt Service (port 8003)"
    echo "  • HTML Frontend Server (port 3001)"
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