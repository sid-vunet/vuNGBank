#!/bin/bash

echo "🔍 === RUM Configuration Synchronization Check ==="
echo "Analyzing if RUM configurations are truly synonymous across all HTML files"
echo ""

# Extract RUM configurations from all files
echo "📊 Extracting RUM configurations..."

# Function to extract RUM config from a file
extract_rum_config() {
    local file="$1"
    local filename=$(basename "$file")
    
    if [ ! -f "$file" ]; then
        return
    fi
    
    # Check if file has RUM config
    if ! grep -q "elasticApm.init" "$file"; then
        return
    fi
    
    echo ""
    echo "📄 === $filename ==="
    echo "Path: $file"
    
    # Extract the elasticApm.init configuration block
    echo "Configuration:"
    
    # Use sed to extract from 'elasticApm.init({' to the matching closing '});'
    awk '/elasticApm\.init\({/,/}\);/' "$file" | head -50
    
    echo "--- End of $filename config ---"
}

# Check all HTML files
echo ""
echo "🔍 Scanning RUM configurations in all HTML files..."

# Frontend directory
for file in /data1/apps/vuNGBank/frontend/*.html; do
    extract_rum_config "$file"
done

# Root directory  
for file in /data1/apps/vuNGBank/*.html; do
    extract_rum_config "$file"
done

# Public directory
for file in /data1/apps/vuNGBank/frontend/public/*.html; do
    extract_rum_config "$file"
done

echo ""
echo "🔧 === Configuration Differences Analysis ==="

# Count unique configurations
echo ""
echo "📊 Analyzing configuration patterns..."

# Create temporary files to compare configurations
temp_dir="/tmp/rum_configs"
mkdir -p "$temp_dir"

config_count=0
for file in /data1/apps/vuNGBank/frontend/*.html /data1/apps/vuNGBank/*.html /data1/apps/vuNGBank/frontend/public/*.html; do
    if [ -f "$file" ] && grep -q "elasticApm.init" "$file"; then
        filename=$(basename "$file")
        config_count=$((config_count + 1))
        
        # Extract just the config object
        awk '/elasticApm\.init\({/,/}\);/' "$file" > "$temp_dir/$filename.config"
    fi
done

echo "Found $config_count RUM configurations"

# Compare configurations for differences
echo ""
echo "🔍 Checking for configuration differences..."

first_config=""
differences_found=false

for config_file in "$temp_dir"/*.config; do
    if [ -z "$first_config" ]; then
        first_config="$config_file"
        continue
    fi
    
    filename=$(basename "$config_file" .config)
    first_filename=$(basename "$first_config" .config)
    
    # Compare ignoring whitespace differences
    if ! diff -w "$first_config" "$config_file" > /dev/null 2>&1; then
        echo "❌ Configuration difference found between $first_filename and $filename"
        differences_found=true
        
        echo "Differences:"
        diff -w "$first_config" "$config_file" | head -20
        echo ""
    fi
done

if [ "$differences_found" = false ]; then
    echo "✅ All RUM configurations are identical (ignoring whitespace)"
else
    echo "⚠️  Configuration differences found between files"
fi

# Clean up
rm -rf "$temp_dir"

echo ""
echo "📋 === Recommendations ==="

if [ "$differences_found" = true ]; then
    echo "❌ RUM configurations are NOT truly synonymous"
    echo "🔧 Recommendation: Standardize all RUM configurations to use identical code"
    echo ""
    echo "Suggested actions:"
    echo "1. Create a single, standardized RUM configuration template"
    echo "2. Apply this template to all HTML files"
    echo "3. Only allow page-specific values for 'pageLoadTransactionName'"
    echo "4. Keep all other configuration properties identical"
else
    echo "✅ RUM configurations are properly synchronized"
    echo "🎯 All HTML files use identical RUM configuration code"
fi

echo ""
echo "✅ RUM synchronization check completed!"