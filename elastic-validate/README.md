# Elastic APM Data Validator

🔍 A comprehensive Go-based tool for validating APM (Application Performance Monitoring) and RUM (Real User Monitoring) data collected in Elasticsearch.

## Overview

This tool helps validate that your APM instrumentation is working correctly by querying Elasticsearch and checking for:
- ✅ Request headers capture
- ✅ Request body capture  
- ✅ Transaction metadata completeness
- ✅ Distributed tracing continuity
- ✅ RUM page load metrics
- ✅ Error capture and reporting
- ✅ Service health monitoring

## Features

### 🎯 APM Validation
- Validates transaction data from backend services
- Checks request headers and bodies are captured
- Verifies transaction metadata completeness
- Validates error capture

### 🌐 RUM Validation  
- Validates frontend Real User Monitoring data
- Checks page load metrics
- Verifies user interaction capture
- Validates navigation timing

### 🔗 Distributed Tracing
- Validates trace continuity across services
- Checks span relationships
- Identifies orphaned spans
- Verifies trace propagation

### 🏥 Health Monitoring
- Service-specific health checks
- Overall APM system health
- Data freshness validation
- Error rate monitoring

### 📦 Bulk Validation
- Run multiple validation tests in parallel
- Predefined test suites
- Comprehensive reporting
- Configuration-driven testing

## Installation

### Prerequisites
- Go 1.21 or later
- Access to Elasticsearch cluster with APM data

### Build from Source
```bash
git clone <repository>
cd elastic-validate
go mod tidy
go build -o elastic-validate ./main.go
```

### Using Makefile
```bash
make build          # Build the binary
make install        # Install system-wide
make test           # Run tests
make clean          # Clean build artifacts
```

## Configuration

### Default Configuration
- **Elasticsearch URL**: `http://91.203.133.240:8082`
- **Index Pattern**: `.ds-*`
- **Time Range**: `24h` (for most queries)

### Environment Variables
```bash
export ELASTIC_URL="http://91.203.133.240:8082"
export ELASTIC_INDEX=".ds-*"
export DEBUG=true
```

## Usage

### Basic Commands

#### APM Validation
```bash
# Validate specific service and transaction
./elastic-validate apm --service="vubank-login-service" --transaction="POST /api/login"

# Validate headers and body capture for a service
./elastic-validate apm --service="payment-process-java-service" --validate-headers --validate-body

# Quick validation with debug output
./elastic-validate apm --service="corebanking-java-service" --debug
```

#### RUM Validation
```bash
# Validate frontend RUM data
./elastic-validate rum --service="vubank-frontend" --page="login"

# Check page load metrics
./elastic-validate rum --service="vubank-frontend" --time-range="1h"
```

#### Distributed Tracing
```bash
# Validate specific trace
./elastic-validate trace --trace-id="abc123def456"

# Check trace continuity
./elastic-validate trace --trace-id="xyz789" --debug
```

#### Health Checks
```bash
# Check single service health
./elastic-validate health --service="vubank-login-service"

# Check all services
./elastic-validate health --check-all

# Health check with custom time range
./elastic-validate health --service="payment-service" --time-range="1h"
```

#### Bulk Validation
```bash
# Run predefined validation suite
./elastic-validate bulk

# Run with custom configuration
./elastic-validate bulk --config="validation-config.yaml" --parallel=5

# Generate JSON report
./elastic-validate bulk --output="validation-report.json" --json
```

### Advanced Usage

#### Global Flags
```bash
--elastic-url       # Elasticsearch URL (default: http://91.203.133.240:8082)
--index-pattern     # Index pattern (default: .ds-*)
--debug            # Enable debug logging
--json             # Output in JSON format
```

#### Time Range Examples
```bash
--time-range="1h"   # Last 1 hour
--time-range="24h"  # Last 24 hours  
--time-range="7d"   # Last 7 days
--time-range="1w"   # Last 1 week
```

## VuBank Services

### Supported Services
The tool is configured to validate the following VuBank services:

| Service Name | Purpose | Port |
|--------------|---------|------|
| `vubank-frontend` | Frontend RUM | 3000 |
| `vubank-login-service` | Authentication | 8000 |
| `payment-process-java-service` | Payment Processing | 8004 |
| `corebanking-java-service` | Core Banking | 8005 |
| `accounts-go-service` | Account Management | 8002 |
| `payee-store-dotnet-service` | Payee Management | 5004 |
| `pdf-receipt-java-service` | Receipt Generation | 8003 |
| `login-python-authenticator` | Auth Validation | 8001 |

### Common Transactions
```bash
# Login flow
./elastic-validate apm --service="vubank-login-service" --transaction="POST /api/login"

# Payment processing
./elastic-validate apm --service="payment-process-java-service" --transaction="POST /api/payment/transfer"

# Account lookup
./elastic-validate apm --service="corebanking-java-service" --transaction="GET /api/accounts"

# Frontend page loads
./elastic-validate rum --service="vubank-frontend" --page="login-page-load"
```

## Output Examples

### Successful APM Validation
```
🔍 Starting APM Validation...
   Service: vubank-login-service
   Transaction: POST /api/login
   Time Range: 24h
   Elasticsearch: http://91.203.133.240:8082

✅ Found 45 APM documents

🔍 Validating Request Headers...
✅ All documents (45/45) have request headers captured

📋 Sample Header Details:
   Document 1:
     authorization: Bearer eyJhbGciOiJIUzI1NiIs...
     content-type: application/json
     user-agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)

🔍 Validating Request Bodies...
✅ All documents (45/45) have request bodies captured

📊 Validation Summary:
   Total Documents: 45
   Headers Present: ✅ Validated
   Request Bodies: ✅ Validated
```

### Health Check Output
```
🏥 Starting Health Check...
   Time Range: 1h
   Elasticsearch: http://91.203.133.240:8082

🔍 Checking all services...

🔍 Checking vubank-frontend...
✅ vubank-frontend: Healthy

🔍 Checking vubank-login-service...
✅ vubank-login-service: Healthy

🔍 Checking payment-process-java-service...
✅ payment-process-java-service: Healthy

📊 Overall Health Summary:
   Healthy Services: 8/8
🎉 All services are healthy!
```

### Bulk Validation Results
```
📦 Starting Bulk Validation...
   Parallel Jobs: 3
   Time Range: 24h

🧪 Running Predefined Validation Suite...

🧪 [1/5] Login Service - Authentication
   Service: vubank-login-service
   Transaction: POST /api/login
   ✅ PASSED

🧪 [2/5] Payment Service - Fund Transfer  
   Service: payment-process-java-service
   Transaction: POST /api/payment/transfer
   ✅ PASSED

📊 Bulk Validation Summary:
   Total Tests: 5
   Passed: 5
   Failed: 0
   Success Rate: 100.0%

🎉 All validation tests passed!
```

## Development

### Project Structure
```
elastic-validate/
├── main.go                    # Entry point
├── go.mod                     # Dependencies
├── Makefile                   # Build automation
├── README.md                  # Documentation
├── internal/
│   ├── commands/             # CLI commands
│   │   ├── apm.go           # APM validation
│   │   ├── rum.go           # RUM validation
│   │   ├── trace.go         # Trace validation
│   │   ├── health.go        # Health checks
│   │   └── bulk.go          # Bulk validation
│   ├── elastic/             # Elasticsearch client
│   │   └── client.go        # ES operations
│   └── validators/          # Validation logic
│       ├── apm.go          # APM validators
│       ├── rum.go          # RUM validators
│       └── trace.go        # Trace validators
```

### Adding New Validations

1. **Create Validator**: Add new validation method to appropriate validator
2. **Add Command**: Create or extend command in `internal/commands/`
3. **Update Bulk**: Add to predefined test suite in `bulk.go`
4. **Test**: Add unit tests for new validation

### Building
```bash
# Development build
go build -o elastic-validate ./main.go

# Production build with optimizations
go build -ldflags="-s -w" -o elastic-validate ./main.go

# Cross-platform builds
GOOS=linux GOARCH=amd64 go build -o elastic-validate-linux ./main.go
GOOS=windows GOARCH=amd64 go build -o elastic-validate.exe ./main.go
```

## Troubleshooting

### Common Issues

#### Connection Errors
```bash
# Test Elasticsearch connection
curl http://91.203.133.240:8082/_cluster/health

# Check with debug logging
./elastic-validate health --debug
```

#### No Documents Found
```bash
# Check index pattern
./elastic-validate health --debug --index-pattern=".ds-*"

# Verify service name
./elastic-validate apm --service="exact-service-name" --debug
```

#### Missing Headers/Bodies
```bash
# Check APM agent configuration
./elastic-validate apm --service="service-name" --debug --validate-headers
```

### Debug Mode
Enable debug logging to see Elasticsearch queries and responses:
```bash
./elastic-validate apm --service="vubank-login-service" --debug
```

### JSON Output
Get machine-readable output for automation:
```bash
./elastic-validate bulk --json > validation-results.json
```

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/new-validation`)
3. Add validation logic and tests
4. Update documentation
5. Submit pull request

## License

MIT License - see LICENSE file for details.

---

🏦 **VuBank NextGen Banking Platform**  
APM Data Validation Tool v1.0.0