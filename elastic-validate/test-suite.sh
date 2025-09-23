#!/bin/bash
# Test script for Elastic APM Data Validator

echo "🔍 VuBank APM Data Validation Test Suite"
echo "========================================"

# Set the Elasticsearch URL
ELASTIC_URL="http://91.203.133.240:8082"

echo ""
echo "1️⃣ Testing basic connectivity..."
./elastic-validate health --elastic-url="$ELASTIC_URL" --debug

echo ""
echo "2️⃣ Testing login service APM validation..."
./elastic-validate apm --service="vubank-login-service" --transaction="POST /api/login" --elastic-url="$ELASTIC_URL" --debug

echo ""
echo "3️⃣ Testing payment service APM validation..."  
./elastic-validate apm --service="payment-process-java-service" --transaction="POST /api/payment/transfer" --elastic-url="$ELASTIC_URL" --debug

echo ""
echo "4️⃣ Testing frontend RUM validation..."
./elastic-validate rum --service="vubank-frontend" --page="login" --elastic-url="$ELASTIC_URL" --debug

echo ""
echo "5️⃣ Running bulk validation..."
./elastic-validate bulk --elastic-url="$ELASTIC_URL" --debug

echo ""
echo "✅ Test suite completed!"
echo ""
echo "📋 Available commands:"
echo "  - APM Validation:    ./elastic-validate apm --service='service-name'"
echo "  - RUM Validation:    ./elastic-validate rum --service='vubank-frontend'" 
echo "  - Trace Validation:  ./elastic-validate trace --trace-id='trace-id'"
echo "  - Health Check:      ./elastic-validate health --check-all"
echo "  - Bulk Validation:   ./elastic-validate bulk"