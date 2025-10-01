#!/bin/bash

echo "🔍 === Comprehensive RUM Configuration Validation ==="
echo "Checking ALL HTML files for consistent RUM configuration"
echo "Date: $(date)"
echo ""

# Initialize counters
TOTAL_HTML_FILES=0
RUM_CONFIGURED_FILES=0
CONSISTENT_CONFIG_FILES=0
INCONSISTENT_FILES=()

# Expected consistent configuration
EXPECTED_SERVICE_NAME="vubank-frontend"
EXPECTED_APM_SERVER="http://91.203.133.240:30200"
EXPECTED_ENVIRONMENT="e2e-240-dev"

# Function to validate RUM configuration in a file
validate_rum_config() {
    local file_path="$1"
    local file_name=$(basename "$file_path")
    
    echo "📄 Analyzing: $file_name"
    echo "   Path: $file_path"
    
    # Check if file exists
    if [ ! -f "$file_path" ]; then
        echo "   ❌ File not found"
        return 1
    fi
    
    # Check if file has any RUM configuration
    if ! grep -q "elastic-apm-rum\|elasticApm" "$file_path"; then
        echo "   ⚪ No RUM configuration found"
        return 0
    fi
    
    echo "   ✅ RUM configuration detected"
    RUM_CONFIGURED_FILES=$((RUM_CONFIGURED_FILES + 1))
    
    # Detailed validation
    local is_consistent=true
    
    # Check service name
    if grep -q "serviceName: '$EXPECTED_SERVICE_NAME'" "$file_path"; then
        echo "   ✅ Service name: $EXPECTED_SERVICE_NAME"
    else
        local found_service=$(grep -o "serviceName: '[^']*'" "$file_path" | head -1)
        echo "   ❌ Service name mismatch: $found_service (expected: serviceName: '$EXPECTED_SERVICE_NAME')"
        is_consistent=false
    fi
    
    # Check APM server URL
    if grep -q "serverUrl: '$EXPECTED_APM_SERVER'" "$file_path"; then
        echo "   ✅ APM server URL: $EXPECTED_APM_SERVER"
    else
        local found_server=$(grep -o "serverUrl: '[^']*'" "$file_path" | head -1)
        echo "   ❌ APM server URL mismatch: $found_server (expected: serverUrl: '$EXPECTED_APM_SERVER')"
        is_consistent=false
    fi
    
    # Check environment
    if grep -q "environment: '$EXPECTED_ENVIRONMENT'" "$file_path"; then
        echo "   ✅ Environment: $EXPECTED_ENVIRONMENT"
    else
        local found_env=$(grep -o "environment: '[^']*'" "$file_path" | head -1)
        echo "   ⚠️  Environment mismatch: $found_env (expected: environment: '$EXPECTED_ENVIRONMENT')"
    fi
    
    # Check key RUM features
    echo "   📊 RUM Features:"
    
    if grep -q "distributedTracing: true" "$file_path"; then
        echo "      ✅ Distributed tracing enabled"
    else
        echo "      ❌ Distributed tracing not enabled"
        is_consistent=false
    fi
    
    if grep -q "transactionSampleRate: 1.0" "$file_path"; then
        echo "      ✅ Transaction sample rate: 100%"
    else
        echo "      ⚠️  Transaction sample rate not 100%"
    fi
    
    if grep -q "spanSampleRate: 1.0" "$file_path"; then
        echo "      ✅ Span sample rate: 100%"
    else
        echo "      ⚠️  Span sample rate not 100%"
    fi
    
    if grep -q "capturePageLoad: true" "$file_path"; then
        echo "      ✅ Page load capture enabled"
    else
        echo "      ⚠️  Page load capture not enabled"
    fi
    
    if grep -q "captureUserInteractions: true" "$file_path"; then
        echo "      ✅ User interactions capture enabled"
    else
        echo "      ⚠️  User interactions capture not enabled"
    fi
    
    if grep -q "captureErrors: true" "$file_path"; then
        echo "      ✅ Error capture enabled"
    else
        echo "      ⚠️  Error capture not enabled"
    fi
    
    # Check page load transaction name
    local page_load_transaction=$(grep -o "pageLoadTransactionName: '[^']*'" "$file_path" | head -1)
    if [ -n "$page_load_transaction" ]; then
        echo "      ✅ Page load transaction: $page_load_transaction"
    else
        echo "      ⚠️  Page load transaction name not set"
    fi
    
    # Check manual transaction start
    if grep -q "startTransaction" "$file_path"; then
        echo "      ✅ Manual transaction start found"
    else
        echo "      ⚠️  Manual transaction start not found"
    fi
    
    if [ "$is_consistent" = true ]; then
        echo "   🎯 Configuration Status: CONSISTENT"
        CONSISTENT_CONFIG_FILES=$((CONSISTENT_CONFIG_FILES + 1))
    else
        echo "   ⚠️  Configuration Status: INCONSISTENT"
        INCONSISTENT_FILES+=("$file_path")
    fi
    
    echo ""
}

# Check all HTML files
echo "🔍 Scanning for HTML files..."
echo ""

# Frontend directory HTML files
echo "📁 Frontend Directory Files:"
for file in /data1/apps/vuNGBank/frontend/*.html; do
    if [ -f "$file" ]; then
        TOTAL_HTML_FILES=$((TOTAL_HTML_FILES + 1))
        validate_rum_config "$file"
    fi
done

# Root directory HTML files
echo "📁 Root Directory Files:"
for file in /data1/apps/vuNGBank/*.html; do
    if [ -f "$file" ]; then
        TOTAL_HTML_FILES=$((TOTAL_HTML_FILES + 1))
        validate_rum_config "$file"
    fi
done

# Public directory HTML files
echo "📁 Public Directory Files:"
for file in /data1/apps/vuNGBank/frontend/public/*.html; do
    if [ -f "$file" ]; then
        TOTAL_HTML_FILES=$((TOTAL_HTML_FILES + 1))
        validate_rum_config "$file"
    fi
done

# Summary
echo "📊 === VALIDATION SUMMARY ==="
echo ""
echo "📈 Statistics:"
echo "   Total HTML files found: $TOTAL_HTML_FILES"
echo "   Files with RUM configuration: $RUM_CONFIGURED_FILES"
echo "   Files with consistent configuration: $CONSISTENT_CONFIG_FILES"
echo "   Files with inconsistent configuration: $((RUM_CONFIGURED_FILES - CONSISTENT_CONFIG_FILES))"
echo ""

# List RUM-configured files
echo "📋 RUM-Configured Files:"
for file in /data1/apps/vuNGBank/frontend/*.html /data1/apps/vuNGBank/*.html /data1/apps/vuNGBank/frontend/public/*.html; do
    if [ -f "$file" ] && grep -q "elastic-apm-rum\|elasticApm" "$file"; then
        file_name=$(basename "$file")
        if grep -q "serviceName: '$EXPECTED_SERVICE_NAME'" "$file"; then
            echo "   ✅ $file_name - Consistent"
        else
            echo "   ❌ $file_name - Inconsistent"
        fi
    fi
done

echo ""

# Recommendations
if [ ${#INCONSISTENT_FILES[@]} -gt 0 ]; then
    echo "⚠️  === INCONSISTENT FILES FOUND ==="
    echo ""
    echo "The following files have RUM configuration but are inconsistent:"
    for file in "${INCONSISTENT_FILES[@]}"; do
        echo "   ❌ $(basename "$file")"
    done
    echo ""
    echo "🔧 Recommended Actions:"
    echo "1. Fix service names to use: '$EXPECTED_SERVICE_NAME'"
    echo "2. Ensure APM server URL is: '$EXPECTED_APM_SERVER'"
    echo "3. Enable distributed tracing: distributedTracing: true"
    echo "4. Set sample rates to 100%: transactionSampleRate: 1.0, spanSampleRate: 1.0"
else
    echo "🎉 === ALL RUM CONFIGURATIONS ARE CONSISTENT ==="
    echo ""
    echo "✅ All HTML files with RUM configuration are properly standardized!"
fi

echo ""
echo "🔍 Expected Standard Configuration:"
echo "   serviceName: '$EXPECTED_SERVICE_NAME'"
echo "   serverUrl: '$EXPECTED_APM_SERVER'"
echo "   environment: '$EXPECTED_ENVIRONMENT'"
echo "   distributedTracing: true"
echo "   transactionSampleRate: 1.0"
echo "   spanSampleRate: 1.0"
echo "   capturePageLoad: true"
echo "   captureUserInteractions: true"
echo "   captureErrors: true"

echo ""
echo "✅ Comprehensive RUM validation completed!"