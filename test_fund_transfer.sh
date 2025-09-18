#!/bin/bash

echo "=== Testing Fund Transfer with Real JWT Token and Transaction Recording ==="
echo

# Test credentials
USERNAME="sidharth"
PASSWORD="password123" 
USER_ID="4"

echo "1. Getting real JWT token from login service..."
LOGIN_RESPONSE=$(curl -s -X POST "http://localhost:8000/api/login" \
  -H "Content-Type: application/json" \
  -H "X-Api-Client: web-portal" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "Origin: http://localhost:3000" \
  -d "{\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\", \"force_login\": true}")

# Extract JWT token from login response
JWT_TOKEN=$(echo "$LOGIN_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)

if [ -z "$JWT_TOKEN" ]; then
    echo "❌ Failed to get JWT token. Login response:"
    echo "$LOGIN_RESPONSE"
    exit 1
fi

echo "✅ Successfully obtained JWT token: ${JWT_TOKEN:0:50}..."
echo

echo "2. Checking initial account balances for user $USER_ID:"
ACCOUNTS_RESPONSE=$(curl -s -X GET "http://localhost:8080/api/v1/accounts/user/$USER_ID" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json")

echo "Accounts response: $ACCOUNTS_RESPONSE"

# Also check via database
docker exec vubank-postgres psql -U vubank_user -d vubank_db -c "SELECT account_number, account_type, balance FROM accounts WHERE user_id = $USER_ID;"
echo

echo "3. Testing fund transfer from savings account (1001234567893) to Priya Sharma (2234567890123456)"
echo "   Amount: ₹500.00"
echo

# Generate a proper UUID for txnRef
TXN_REF=$(uuidgen)
echo "Generated transaction reference: $TXN_REF"
echo

# Create a test payment request JSON that matches what the frontend would send
cat > /tmp/test_payment.json << EOF
{
  "txnRef": "$TXN_REF",
  "paymentType": "NEFT",
  "amount": 500.00,
  "currency": "INR",
  "payer": {
    "name": "Test User 4",
    "accountNo": "1001234567893"
  },
  "payee": {
    "name": "Priya Sharma",
    "accountNo": "2234567890123456",
    "ifsc": "SBIN0000123"
  },
  "meta": {
    "comments": "Test transfer with real JWT token",
    "initiatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF

echo "4. Sending payment request to Core Banking Service:"
curl -X POST http://localhost:8005/core/payments \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "X-Request-Id: $(uuidgen)" \
  -H "X-Origin-Service: payment-process" \
  -H "X-Txn-Ref: $TXN_REF" \
  -d @/tmp/test_payment.json
echo
echo

echo "5. Checking balance after transaction:"
sleep 2
docker exec vubank-postgres psql -U vubank_user -d vubank_db -c "SELECT account_number, account_type, balance FROM accounts WHERE user_id = $USER_ID;"
echo

echo "6. Checking core_payments table for transaction record:"
docker exec vubank-postgres psql -U vubank_user -d vubank_db -c "SELECT id, payer_account, payee_account, amount, status, created_at FROM core_payments WHERE payer_account = '1001234567893' ORDER BY created_at DESC LIMIT 1;"
echo

echo "7. Checking transactions table for user's transaction history:"
docker exec vubank-postgres psql -U vubank_user -d vubank_db -c "SELECT t.id, t.transaction_type, t.amount, t.description, t.balance_after FROM transactions t JOIN accounts a ON t.account_id = a.id WHERE a.user_id = $USER_ID ORDER BY t.transaction_date DESC LIMIT 2;"
echo

# Clean up
rm -f /tmp/test_payment.json

echo "=== Test Complete ==="