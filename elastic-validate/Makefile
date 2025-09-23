# Makefile for Elastic APM Data Validator

# Build configuration
BINARY_NAME=elastic-validate
MAIN_PATH=./main.go
BUILD_DIR=./bin
VERSION=$(shell git describe --tags --always --dirty)
COMMIT=$(shell git rev-parse --short HEAD)
DATE=$(shell date -u '+%Y-%m-%d_%H:%M:%S')
LDFLAGS=-ldflags "-X main.version=${VERSION} -X main.commit=${COMMIT} -X main.date=${DATE}"

# Go configuration  
GOOS=$(shell go env GOOS)
GOARCH=$(shell go env GOARCH)
GO=go

.PHONY: help build clean test install deps run dev lint fmt vet check cross-compile docker

# Default target
all: clean deps test build

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Dependencies
deps: ## Install dependencies
	@echo "📦 Installing dependencies..."
	$(GO) mod download
	$(GO) mod tidy

# Development
dev: deps ## Run in development mode with hot reload
	@echo "🔧 Starting development mode..."
	$(GO) run $(MAIN_PATH) health --check-all --debug

run: ## Run the application with default health check
	@echo "🚀 Running elastic-validate..."
	$(GO) run $(MAIN_PATH) health --check-all

# Building
build: deps ## Build the binary
	@echo "🔨 Building $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(GO) build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME) $(MAIN_PATH)
	@echo "✅ Build complete: $(BUILD_DIR)/$(BINARY_NAME)"

build-optimized: deps ## Build optimized binary (smaller size)
	@echo "🔨 Building optimized $(BINARY_NAME)..."
	@mkdir -p $(BUILD_DIR)
	$(GO) build $(LDFLAGS) -ldflags="-s -w" -o $(BUILD_DIR)/$(BINARY_NAME) $(MAIN_PATH)
	@echo "✅ Optimized build complete: $(BUILD_DIR)/$(BINARY_NAME)"

# Cross-compilation
cross-compile: deps ## Build for multiple platforms
	@echo "🔨 Cross-compiling for multiple platforms..."
	@mkdir -p $(BUILD_DIR)
	
	# Linux AMD64
	GOOS=linux GOARCH=amd64 $(GO) build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-amd64 $(MAIN_PATH)
	
	# Linux ARM64
	GOOS=linux GOARCH=arm64 $(GO) build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-linux-arm64 $(MAIN_PATH)
	
	# macOS AMD64
	GOOS=darwin GOARCH=amd64 $(GO) build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-amd64 $(MAIN_PATH)
	
	# macOS ARM64 (Apple Silicon)
	GOOS=darwin GOARCH=arm64 $(GO) build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-darwin-arm64 $(MAIN_PATH)
	
	# Windows AMD64
	GOOS=windows GOARCH=amd64 $(GO) build $(LDFLAGS) -o $(BUILD_DIR)/$(BINARY_NAME)-windows-amd64.exe $(MAIN_PATH)
	
	@echo "✅ Cross-compilation complete"
	@ls -la $(BUILD_DIR)/

# Installation
install: build ## Install binary to system PATH
	@echo "📥 Installing $(BINARY_NAME)..."
	@sudo cp $(BUILD_DIR)/$(BINARY_NAME) /usr/local/bin/$(BINARY_NAME)
	@echo "✅ Installed to /usr/local/bin/$(BINARY_NAME)"

uninstall: ## Uninstall binary from system PATH
	@echo "🗑️ Uninstalling $(BINARY_NAME)..."
	@sudo rm -f /usr/local/bin/$(BINARY_NAME)
	@echo "✅ Uninstalled"

# Testing
test: deps ## Run tests
	@echo "🧪 Running tests..."
	$(GO) test -v ./...

test-race: deps ## Run tests with race condition detection
	@echo "🧪 Running tests with race detection..."
	$(GO) test -race -v ./...

test-coverage: deps ## Run tests with coverage
	@echo "🧪 Running tests with coverage..."
	$(GO) test -coverprofile=coverage.out ./...
	$(GO) tool cover -html=coverage.out -o coverage.html
	@echo "📊 Coverage report: coverage.html"

benchmark: deps ## Run benchmarks
	@echo "📈 Running benchmarks..."
	$(GO) test -bench=. -benchmem ./...

# Code quality
lint: ## Run linter
	@echo "🔍 Running linter..."
	@which golangci-lint > /dev/null || (echo "Installing golangci-lint..." && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest)
	golangci-lint run

fmt: ## Format code
	@echo "📝 Formatting code..."
	$(GO) fmt ./...

vet: ## Run go vet
	@echo "🔍 Running go vet..."
	$(GO) vet ./...

check: fmt vet lint test ## Run all checks (format, vet, lint, test)

# Validation Commands
validate-login: build ## Quick validation of login service
	@echo "🔍 Validating login service..."
	$(BUILD_DIR)/$(BINARY_NAME) apm --service="vubank-login-service" --transaction="POST /api/login"

validate-payment: build ## Quick validation of payment service  
	@echo "🔍 Validating payment service..."
	$(BUILD_DIR)/$(BINARY_NAME) apm --service="payment-process-java-service" --transaction="POST /api/payment/transfer"

validate-rum: build ## Quick validation of frontend RUM
	@echo "🔍 Validating frontend RUM..."
	$(BUILD_DIR)/$(BINARY_NAME) rum --service="vubank-frontend" --page="login"

validate-all: build ## Run bulk validation suite
	@echo "🔍 Running bulk validation..."
	$(BUILD_DIR)/$(BINARY_NAME) bulk

health-check: build ## Quick health check of all services
	@echo "🏥 Running health check..."
	$(BUILD_DIR)/$(BINARY_NAME) health --check-all

# Docker
docker-build: ## Build Docker image
	@echo "🐳 Building Docker image..."
	docker build -t elastic-validate:$(VERSION) .
	docker tag elastic-validate:$(VERSION) elastic-validate:latest

docker-run: docker-build ## Run in Docker container
	@echo "🐳 Running in Docker..."
	docker run --rm -it elastic-validate:latest health --check-all

# Utility
version: ## Show version information
	@echo "Version: $(VERSION)"
	@echo "Commit: $(COMMIT)" 
	@echo "Built: $(DATE)"
	@echo "GOOS: $(GOOS)"
	@echo "GOARCH: $(GOARCH)"

clean: ## Clean build artifacts
	@echo "🧹 Cleaning..."
	@rm -rf $(BUILD_DIR)
	@rm -f coverage.out coverage.html
	@echo "✅ Clean complete"

clean-deps: ## Clean dependencies
	@echo "🧹 Cleaning dependencies..."
	$(GO) clean -modcache
	@echo "✅ Dependencies cleaned"

# Release
release-prep: clean check cross-compile ## Prepare release builds
	@echo "📦 Release preparation complete"
	@echo "Built binaries:"
	@ls -la $(BUILD_DIR)/

# Quick development workflows
quick-test: ## Quick test and build cycle
	@echo "⚡ Quick test cycle..."
	$(MAKE) fmt test build

quick-validate: build ## Quick validation of key services
	@echo "⚡ Quick validation..."
	$(BUILD_DIR)/$(BINARY_NAME) health --service="vubank-login-service"
	$(BUILD_DIR)/$(BINARY_NAME) apm --service="payment-process-java-service"

# Help with common tasks
demo: build ## Run demo validation commands
	@echo "🎬 Running demo validation..."
	@echo "\n1️⃣ Health Check:"
	$(BUILD_DIR)/$(BINARY_NAME) health --check-all --time-range="1h"
	@echo "\n2️⃣ APM Validation:"
	$(BUILD_DIR)/$(BINARY_NAME) apm --service="vubank-login-service" --validate-headers
	@echo "\n3️⃣ RUM Validation:"
	$(BUILD_DIR)/$(BINARY_NAME) rum --service="vubank-frontend"
	@echo "\n4️⃣ Bulk Validation:"
	$(BUILD_DIR)/$(BINARY_NAME) bulk

# Integration with VuBank services
vubank-check: build ## Check all VuBank services
	@echo "🏦 VuBank Service Validation..."
	$(BUILD_DIR)/$(BINARY_NAME) health --check-all
	$(BUILD_DIR)/$(BINARY_NAME) apm --service="vubank-login-service"
	$(BUILD_DIR)/$(BINARY_NAME) apm --service="payment-process-java-service" 
	$(BUILD_DIR)/$(BINARY_NAME) apm --service="corebanking-java-service"
	$(BUILD_DIR)/$(BINARY_NAME) rum --service="vubank-frontend"

# Development helpers
watch: ## Watch for file changes and rebuild (requires entr)
	@echo "👁️ Watching for changes..."
	@which entr > /dev/null || (echo "Install 'entr' for file watching" && exit 1)
	find . -name "*.go" | entr -r make quick-test

debug-build: ## Build with debug symbols
	@echo "🔨 Building debug version..."
	@mkdir -p $(BUILD_DIR)
	$(GO) build -gcflags="all=-N -l" -o $(BUILD_DIR)/$(BINARY_NAME)-debug $(MAIN_PATH)

profile: build ## Run with CPU profiling
	@echo "📊 Running with CPU profiling..."
	$(BUILD_DIR)/$(BINARY_NAME) bulk --cpuprofile=cpu.prof
	go tool pprof cpu.prof