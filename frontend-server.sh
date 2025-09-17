#!/bin/bash

# VuBank Static Frontend Server
# Simple HTTP server for the multi-page HTML frontend

set -e

# Configuration
FRONTEND_DIR="/Users/sidharthan/Documents/vuNGBank/frontend"
FRONTEND_PORT=3001
SERVER_PID_FILE="/Users/sidharthan/Documents/vuNGBank/frontend-server.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Python 3 is available
check_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null && python --version 2>&1 | grep -q "Python 3"; then
        PYTHON_CMD="python"
    else
        print_error "Python 3 is required but not found. Please install Python 3."
        exit 1
    fi
}

# Start the frontend server
start_server() {
    check_python
    
    print_status "Starting VuBank frontend server on port $FRONTEND_PORT..."
    
    # Kill any existing server
    stop_server 2>/dev/null || true
    
    # Change to frontend directory
    cd "$FRONTEND_DIR"
    
    # Start Python HTTP server in background
    nohup $PYTHON_CMD -m http.server $FRONTEND_PORT > frontend-server.log 2>&1 &
    SERVER_PID=$!
    
    # Save PID
    echo $SERVER_PID > "$SERVER_PID_FILE"
    
    # Wait a moment for server to start
    sleep 2
    
    # Check if server started successfully
    if kill -0 $SERVER_PID 2>/dev/null; then
        print_success "Frontend server started successfully (PID: $SERVER_PID)"
        print_status "Access your application at: http://localhost:$FRONTEND_PORT"
        print_status "Available pages:"
        print_status "  • http://localhost:$FRONTEND_PORT/index.html (Entry point)"
        print_status "  • http://localhost:$FRONTEND_PORT/login.html (Login page)"
        print_status "  • http://localhost:$FRONTEND_PORT/dashboard.html (Dashboard)"
    else
        print_error "Failed to start frontend server"
        exit 1
    fi
}

# Stop the frontend server
stop_server() {
    if [ -f "$SERVER_PID_FILE" ]; then
        SERVER_PID=$(cat "$SERVER_PID_FILE")
        if kill -0 $SERVER_PID 2>/dev/null; then
            kill $SERVER_PID
            print_success "Frontend server stopped (PID: $SERVER_PID)"
        else
            print_status "Frontend server was not running"
        fi
        rm -f "$SERVER_PID_FILE"
    else
        # Try to kill any Python HTTP server on our port
        pkill -f "python.*http.server.*$FRONTEND_PORT" 2>/dev/null || true
        print_status "No PID file found, attempted to kill any HTTP server on port $FRONTEND_PORT"
    fi
}

# Check server status
check_status() {
    if [ -f "$SERVER_PID_FILE" ]; then
        SERVER_PID=$(cat "$SERVER_PID_FILE")
        if kill -0 $SERVER_PID 2>/dev/null; then
            print_success "Frontend server is running (PID: $SERVER_PID)"
            print_status "Access at: http://localhost:$FRONTEND_PORT"
        else
            print_error "Frontend server is not running (stale PID file)"
            rm -f "$SERVER_PID_FILE"
        fi
    else
        print_status "Frontend server is not running"
    fi
}

# Show server logs
show_logs() {
    if [ -f "$FRONTEND_DIR/frontend-server.log" ]; then
        echo "=== Frontend Server Logs ==="
        tail -f "$FRONTEND_DIR/frontend-server.log"
    else
        print_error "No log file found"
    fi
}

# Main command handler
case "$1" in
    start)
        start_server
        ;;
    stop)
        stop_server
        ;;
    restart)
        stop_server
        start_server
        ;;
    status)
        check_status
        ;;
    logs)
        show_logs
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs}"
        echo ""
        echo "VuBank Static Frontend Server"
        echo "Commands:"
        echo "  start   - Start the frontend HTTP server"
        echo "  stop    - Stop the frontend HTTP server"
        echo "  restart - Restart the frontend HTTP server"
        echo "  status  - Check server status"
        echo "  logs    - Show server logs (tail -f)"
        echo ""
        echo "The server will serve files from: $FRONTEND_DIR"
        echo "Server will run on: http://localhost:$FRONTEND_PORT"
        exit 1
        ;;
esac