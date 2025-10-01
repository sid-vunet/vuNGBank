#!/bin/bash

echo "🔧 === Standardizing RUM Configurations ==="
echo "Applying identical RUM configuration to all HTML files"
echo ""

# Read the standard configuration template
STANDARD_CONFIG=$(cat /data1/apps/vuNGBank/standard_rum_config.js)

# Function to apply standard RUM config to a file
standardize_rum_config() {
    local file_path="$1"
    local page_transaction_name="$2"
    local filename=$(basename "$file_path")
    
    echo "📄 Standardizing: $filename"
    
    if [ ! -f "$file_path" ]; then
        echo "   ❌ File not found"
        return 1
    fi
    
    # Check if file has RUM configuration
    if ! grep -q "elasticApm.init" "$file_path"; then
        echo "   ⚪ No RUM configuration - skipping"
        return 0
    fi
    
    # Create backup
    cp "$file_path" "$file_path.backup"
    
    # Replace the page-specific transaction name in the template
    local customized_config="${STANDARD_CONFIG/PAGE_SPECIFIC_TRANSACTION_NAME/$page_transaction_name}"
    
    # Create temporary file with the new configuration
    temp_file=$(mktemp)
    
    # Extract everything before elasticApm.init
    awk '/elasticApm\.init\({/{exit} 1' "$file_path" > "$temp_file"
    
    # Add the standardized configuration
    echo "        // =======================================" >> "$temp_file"
    echo "        // STANDARD VUBANK RUM CONFIGURATION" >> "$temp_file"
    echo "        // =======================================" >> "$temp_file"
    echo "" >> "$temp_file"
    echo "        $customized_config" >> "$temp_file"
    echo "" >> "$temp_file"
    
    # Add everything after the closing }); of elasticApm.init
    awk '
        /elasticApm\.init\({/ { in_init = 1; brace_count = 1; next }
        in_init {
            for (i = 1; i <= length($0); i++) {
                char = substr($0, i, 1)
                if (char == "{") brace_count++
                if (char == "}") brace_count--
                if (brace_count == 0 && char == "}") {
                    # Found the closing brace, check if followed by );
                    rest = substr($0, i+1)
                    if (match(rest, /^\s*\)\s*;/)) {
                        # Skip the ); part and continue from after it
                        remaining = substr(rest, RSTART + RLENGTH)
                        if (remaining) print remaining
                        in_init = 0
                        next
                    }
                }
            }
            next
        }
        !in_init { print }
    ' "$file_path" >> "$temp_file"
    
    # Replace the original file
    mv "$temp_file" "$file_path"
    
    echo "   ✅ Configuration standardized with transaction: $page_transaction_name"
}

# Apply standardized configuration to all RUM-enabled HTML files
echo "🎯 Applying standard configuration..."
echo ""

# Frontend directory files
standardize_rum_config "/data1/apps/vuNGBank/frontend/FundTransfer.html" "vubank-fundtransfer-page-load"
standardize_rum_config "/data1/apps/vuNGBank/frontend/dashboard.html" "vubank-dashboard-page-load"
standardize_rum_config "/data1/apps/vuNGBank/frontend/index.html" "vubank-index-page-load"
standardize_rum_config "/data1/apps/vuNGBank/frontend/login.html" "vubank-login-page-load"
standardize_rum_config "/data1/apps/vuNGBank/frontend/rum-test.html" "vubank-rum-test-page-load"
standardize_rum_config "/data1/apps/vuNGBank/frontend/trace-test.html" "vubank-trace-test-page-load"

# Root directory files
standardize_rum_config "/data1/apps/vuNGBank/rum-login-test.html" "vubank-rum-login-test-page-load"
standardize_rum_config "/data1/apps/vuNGBank/rum-trace-test.html" "vubank-rum-trace-test-page-load"
standardize_rum_config "/data1/apps/vuNGBank/rum-transaction-test.html" "vubank-rum-transaction-test-page-load"

# Public directory files
standardize_rum_config "/data1/apps/vuNGBank/frontend/public/index.html" "vubank-public-index-page-load"

echo ""
echo "📊 === Standardization Summary ==="
echo ""

# Verify standardization
echo "🔍 Verifying standardization..."

all_identical=true
first_config=""

for file in /data1/apps/vuNGBank/frontend/*.html /data1/apps/vuNGBank/*.html /data1/apps/vuNGBank/frontend/public/*.html; do
    if [ -f "$file" ] && grep -q "elasticApm.init" "$file"; then
        # Extract configuration (excluding pageLoadTransactionName line)
        config=$(awk '/elasticApm\.init\({/,/}\);/' "$file" | grep -v "pageLoadTransactionName")
        
        if [ -z "$first_config" ]; then
            first_config="$config"
        elif [ "$config" != "$first_config" ]; then
            echo "❌ Configuration still differs in $(basename "$file")"
            all_identical=false
        fi
    fi
done

if [ "$all_identical" = true ]; then
    echo "✅ All RUM configurations are now identical (except pageLoadTransactionName)"
else
    echo "⚠️  Some configurations still differ"
fi

echo ""
echo "📋 Standardized Transaction Names:"
for file in /data1/apps/vuNGBank/frontend/*.html /data1/apps/vuNGBank/*.html /data1/apps/vuNGBank/frontend/public/*.html; do
    if [ -f "$file" ] && grep -q "pageLoadTransactionName" "$file"; then
        filename=$(basename "$file")
        transaction=$(grep -o "pageLoadTransactionName: '[^']*'" "$file" | head -1)
        echo "   $filename: $transaction"
    fi
done

echo ""
echo "🎉 RUM configuration standardization completed!"
echo ""
echo "📝 Standard Features Applied:"
echo "   ✅ Unified service name: vubank-frontend"
echo "   ✅ Consistent APM server: http://91.203.133.240:30200"
echo "   ✅ Standard environment: e2e-240-dev"
echo "   ✅ Identical distributed tracing origins"
echo "   ✅ 100% sampling rates"
echo "   ✅ All monitoring features enabled"
echo "   ✅ Consistent configuration structure"
echo "   ✅ Page-specific transaction names only"