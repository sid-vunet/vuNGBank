#!/bin/bash

echo "🔍 Debugging Login Page Load Transaction Issue"
echo "=============================================="

echo ""
echo "❓ ISSUE: Seeing 'vubank-index-page-load' but not 'login-page-load' transactions"

echo ""
echo "🔍 Checking RUM Configuration Consistency:"

echo ""
echo "📄 Index Page RUM Config:"
echo "  • Service Name: $(grep -o "serviceName: '[^']*'" /data1/apps/vuNGBank/frontend/index.html | cut -d"'" -f2)"
echo "  • Server URL: $(grep -o "serverUrl: '[^']*'" /data1/apps/vuNGBank/frontend/index.html | cut -d"'" -f2)"
echo "  • Environment: $(grep -o "environment: '[^']*'" /data1/apps/vuNGBank/frontend/index.html | cut -d"'" -f2)"
echo "  • Page Load Name: $(grep -o "pageLoadTransactionName: '[^']*'" /data1/apps/vuNGBank/frontend/index.html | cut -d"'" -f2)"

echo ""
echo "📄 Login Page RUM Config:"
echo "  • Service Name: $(grep -o "serviceName: '[^']*'" /data1/apps/vuNGBank/frontend/login.html | cut -d"'" -f2)"
echo "  • Server URL: $(grep -o "serverUrl: '[^']*'" /data1/apps/vuNGBank/frontend/login.html | cut -d"'" -f2)"
echo "  • Environment: $(grep -o "environment: '[^']*'" /data1/apps/vuNGBank/frontend/login.html | cut -d"'" -f2)"
echo "  • Page Load Name: $(grep -o "pageLoadTransactionName: '[^']*'" /data1/apps/vuNGBank/frontend/login.html | cut -d"'" -f2)"

echo ""
echo "🔍 Checking Page Accessibility:"

echo -n "  • Index page accessible: "
if curl -s -I http://localhost:8086/index.html | grep -q "200 OK"; then
    echo "✅ YES"
else
    echo "❌ NO"
fi

echo -n "  • Login page accessible: "
if curl -s -I http://localhost:8086/login.html | grep -q "200 OK"; then
    echo "✅ YES"
else
    echo "❌ NO"
fi

echo ""
echo "🔍 Navigation Flow Analysis:"
echo "  • Index page navigation method: window.location.href = page"
echo "  • This should trigger a full page reload -> new page-load transaction"

echo ""
echo "🧪 Potential Issues:"
echo ""
echo "1. 🕒 TIMING ISSUE:"
echo "   • Index loads -> starts 'vubank-index-page-load' transaction"
echo "   • Navigation to login happens after 1.5s delay"
echo "   • If index transaction is still active, it might interfere"

echo ""
echo "2. 🔧 RUM INITIALIZATION TIMING:"
echo "   • Login page might load before RUM library is fully initialized"
echo "   • Check browser console for RUM initialization messages"

echo ""
echo "3. 🌐 BROWSER CACHE:"
echo "   • Login page might be cached, preventing new page-load transaction"
echo "   • Check if login.html has cache-control headers"

echo ""
echo "4. 📊 TRANSACTION SAMPLING:"
echo "   • Both pages have transactionSampleRate: 1.0 (100%)"
echo "   • This should not be the issue"

echo ""
echo "🔧 Debugging Steps:"
echo ""
echo "1. Open browser dev tools -> Network tab"
echo "2. Go to http://localhost:8086/"
echo "3. Watch for:"
echo "   • RUM library loading: /elastic-apm-rum.js"
echo "   • RUM initialization console messages"
echo "   • APM requests to :30200 endpoint"
echo "4. Navigate to login and repeat observation"

echo ""
echo "5. Check APM server for transactions:"
echo "   • Look for both 'vubank-index-page-load' and 'login-page-load'"
echo "   • Check timestamps to see timing differences"

echo ""
echo "📋 Quick Test Commands:"
echo "  # Test direct login page access (should generate transaction)"
echo "  curl -s 'http://localhost:8086/login.html' > /dev/null"
echo "  # Wait and check APM for 'login-page-load' transaction"

echo ""
echo "🎯 Expected Behavior:"
echo "  ✅ Index page load -> 'vubank-index-page-load' transaction"
echo "  ✅ Navigation to login -> 'login-page-load' transaction"
echo "  ✅ Both transactions should appear in APM within ~30 seconds"

echo ""
echo "=============================================="