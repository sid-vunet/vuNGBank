#!/bin/bash

# Build script for VuBank HTML Frontend Container
# This builds a traditional multi-page application in a container

set -e

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

print_header() {
    echo ""
    echo "=========================================="
    echo "     VuBank HTML Frontend Builder"
    echo "=========================================="
    echo ""
}

print_header

print_status "Building traditional multi-page HTML frontend container..."
echo ""

# Check if we're in the right directory
if [[ ! -f "index.html" ]]; then
    print_error "Please run this script from the frontend directory"
    exit 1
fi

# Check required files
REQUIRED_FILES=("index.html" "login.html" "dashboard.html" "FundTransfer.html" "Dockerfile.html" "nginx.conf")
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        print_error "Required file missing: $file"
        exit 1
    fi
done

print_success "All required files found"

# Build the Docker image with --no-cache for fresh build
print_status "Building Docker image: vubank-html-frontend (fresh build, no cache)"
docker build --no-cache -f Dockerfile.html -t vubank-html-frontend .

if [[ $? -eq 0 ]]; then
    print_success "Docker image built successfully!"
    echo ""
    
    print_status "Image details:"
    docker images | grep vubank-html-frontend
    echo ""
    
    print_status "To run the container manually:"
    echo "  docker run -d -p 3001:80 --name vubank-html-frontend vubank-html-frontend"
    echo ""
    
    print_status "Or use the updated docker-compose:"
    echo "  docker-compose --profile html-frontend up -d"
    echo ""
    
    print_status "The HTML frontend will be available at:"
    echo "  • http://localhost:3001/"
    echo "  • http://localhost:3001/login"
    echo "  • http://localhost:3001/dashboard"
    echo "  • http://localhost:3001/transfer"
    echo ""
    
    print_success "Build completed successfully! 🎉"
else
    print_error "Docker build failed"
    exit 1
fi