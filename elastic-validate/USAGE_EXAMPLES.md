# Elastic APM Data Validator - Usage Examples

This document provides practical examples for using the Elastic APM Data Validator with the VuBank system.

## Quick Start Examples

### 1. Basic Health Check
```bash
# Check if all VuBank services are healthy
./elastic-validate health --check-all

# Check specific service health
./elastic-validate health --service="vubank-login-service" --time-range="1h"
```

### 2. APM Transaction Validation
```bash
# Validate login service with headers and body
./elastic-validate apm \
  --service="vubank-login-service" \
  --transaction="POST /api/login" \
  --validate-headers \
  --validate-body

# Quick payment service validation
./elastic-validate apm --service="payment-process-java-service" --debug

# Core banking service validation with custom time range
./elastic-validate apm \
  --service="corebanking-java-service" \
  --transaction="GET /api/accounts" \
  --time-range="6h"
```

### 3. RUM (Frontend) Validation
```bash
# Validate frontend RUM data
./elastic-validate rum --service="vubank-frontend" --page="login"

# Check page load metrics for dashboard
./elastic-validate rum \
  --service="vubank-frontend" \
  --page="dashboard" \
  --time-range="2h"
```

### 4. Distributed Tracing
```bash
# Validate trace continuity
./elastic-validate trace --trace-id="abc123def456789"

# Debug trace with detailed output
./elastic-validate trace --trace-id="trace-id" --debug
```

### 5. Bulk Validation
```bash
# Run complete validation suite
./elastic-validate bulk

# Run with custom configuration
./elastic-validate bulk --config="validation-config.yaml" --parallel=5

# Generate JSON report for automation
./elastic-validate bulk --json --output="results.json"
```

## VuBank-Specific Examples

### Login Flow Validation
```bash
# Validate complete login flow
./elastic-validate apm --service="vubank-login-service" --transaction="POST /api/login"
./elastic-validate apm --service="login-python-authenticator" --transaction="POST /api/validate"
./elastic-validate rum --service="vubank-frontend" --page="login-page-load"

# Alternative: Use bulk validation
./elastic-validate bulk --config="validation-config.yaml"
```

### Payment Processing Validation
```bash
# Validate payment processing chain
./elastic-validate apm --service="payment-process-java-service" --transaction="POST /api/payment/transfer" --debug
./elastic-validate apm --service="corebanking-java-service" --transaction="POST /api/transfer"
./elastic-validate apm --service="pdf-receipt-java-service" --transaction="POST /api/receipt/generate"
```

### Account Management Validation
```bash
# Validate account operations
./elastic-validate apm --service="accounts-go-service" --transaction="GET /api/balance"
./elastic-validate apm --service="accounts-go-service" --transaction="POST /api/account/details"
```

### Payee Management Validation
```bash
# Validate payee operations
./elastic-validate apm --service="payee-store-dotnet-service" --transaction="GET /api/payees"
./elastic-validate apm --service="payee-store-dotnet-service" --transaction="POST /api/payee"
```

## Debugging Examples

### Find Missing Headers
```bash
# Check if request headers are being captured
./elastic-validate apm \
  --service="payment-process-java-service" \
  --validate-headers \
  --debug

# Expected output shows which documents have headers
```

### Find Missing Request Bodies
```bash
# Check if request bodies are being captured
./elastic-validate apm \
  --service="vubank-login-service" \
  --transaction="POST /api/login" \
  --validate-body \
  --debug
```

### Trace Missing Data
```bash
# Find why no APM data exists for a service
./elastic-validate health --service="service-name" --debug

# Check with different time ranges
./elastic-validate apm --service="service-name" --time-range="1h" --debug
./elastic-validate apm --service="service-name" --time-range="24h" --debug
```

### Custom Elasticsearch Configuration
```bash
# Use different Elasticsearch endpoint
./elastic-validate apm \
  --service="vubank-login-service" \
  --elastic-url="http://custom-es:9200" \
  --index-pattern="apm-*"

# Use with authentication (if needed)
export ES_USERNAME="username"
export ES_PASSWORD="password"  
./elastic-validate health --check-all --debug
```

## Automation Examples

### CI/CD Integration
```bash
#!/bin/bash
# APM validation in CI/CD pipeline

# Run health check
./elastic-validate health --check-all --json > health.json

# Check exit code
if [ $? -eq 0 ]; then
    echo "✅ Health check passed"
else
    echo "❌ Health check failed"
    exit 1
fi

# Run bulk validation
./elastic-validate bulk --json --output="validation-results.json"

# Parse results for CI/CD
success_rate=$(cat validation-results.json | jq '.success_rate')
if (( $(echo "$success_rate < 90" | bc -l) )); then
    echo "❌ Validation success rate too low: $success_rate%"
    exit 1
fi
```

### Monitoring Script
```bash
#!/bin/bash
# Continuous monitoring script

while true; do
    echo "$(date): Running APM validation..."
    
    ./elastic-validate health --check-all --json > /tmp/health.json
    
    if [ $? -ne 0 ]; then
        # Send alert
        echo "ALERT: APM health check failed at $(date)"
        # Add your alerting logic here
    fi
    
    sleep 300  # Check every 5 minutes
done
```

### Report Generation
```bash
# Generate comprehensive report
./elastic-validate bulk --json --output="daily-report-$(date +%Y%m%d).json"

# Convert to HTML report (requires additional tooling)
python3 generate_html_report.py daily-report-$(date +%Y%m%d).json
```

## Common Use Cases

### 1. New Service Onboarding
```bash
# Validate new service APM instrumentation
./elastic-validate apm --service="new-service-name" --debug
./elastic-validate health --service="new-service-name" --time-range="1h"
```

### 2. Performance Investigation
```bash
# Check if performance data is being captured
./elastic-validate apm \
  --service="slow-service" \
  --time-range="1h" \
  --debug

# Look for specific high-latency transactions
./elastic-validate apm \
  --service="service-name" \
  --transaction="slow-endpoint" \
  --debug
```

### 3. Error Analysis
```bash
# Validate error capture
./elastic-validate apm \
  --service="error-prone-service" \
  --time-range="1h" \
  --debug
```

### 4. Distributed Tracing Debug
```bash
# Find broken traces
./elastic-validate trace --trace-id="suspected-broken-trace" --debug

# Validate trace continuity
./elastic-validate bulk  # Includes trace validation
```

## Output Interpretation

### Successful Validation Output
```
✅ Found 45 APM documents
✅ All documents (45/45) have request headers captured
✅ All documents (45/45) have request bodies captured
```

### Warning Output
```
⚠️  Partial header capture: 30/45 documents have headers
❌ Missing headers in 15 documents
```

### Error Output
```
❌ No APM documents found matching criteria
❌ Connection failed to Elasticsearch
❌ No request headers found in any documents
```

## Troubleshooting

### Connection Issues
```bash
# Test connectivity
curl http://91.203.133.240:8082/_cluster/health

# Use debug mode
./elastic-validate health --debug --elastic-url="http://91.203.133.240:8082"
```

### No Data Found
```bash
# Check index pattern
./elastic-validate health --index-pattern=".ds-apm-*" --debug

# Check time range
./elastic-validate apm --service="service-name" --time-range="7d" --debug
```

### Service Name Issues
```bash
# List all available services (requires custom query)
./elastic-validate health --check-all --debug

# Try partial service name
./elastic-validate apm --service="login" --debug
```