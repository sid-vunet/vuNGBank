# VuBank NextGen Banking Platform - API Reference

## Overview

The VuBank API is organized into four main services:
- **Login Gateway Service** (Port 8000): Public authentication and JWT token management
- **Authentication Service** (Port 8001): Internal credential verification and session management
- **Accounts Service** (Port 8002): Protected account and transaction data
- **PDF Receipt Service** (Port 8003): Professional PDF receipt generation

All APIs follow REST principles with JSON request/response bodies and standard HTTP status codes.

## Base URLs

```
Development Environment:
- Login Gateway:    http://localhost:8000
- Auth Service:     http://localhost:8001  (Internal)
- Accounts Service: http://localhost:8002  (Internal)
- PDF Service:      http://localhost:8003

Production Environment:
- Login Gateway:    https://api.vubank.com
- Auth Service:     http://auth-service:8001  (Internal)
- Accounts Service: http://accounts-service:8002  (Internal)
- PDF Service:      http://pdf-service:8003  (Internal)
```

## Authentication Flow

### JWT Token Structure
```json
{
  "header": {
    "alg": "HS256",
    "typ": "JWT"
  },
  "payload": {
    "user_id": "1",
    "roles": ["retail"],
    "exp": 1640995200,
    "iat": 1640991600,
    "iss": "vubank-login-service"
  }
}
```

**Token Expiry**: 15 minutes  
**Signing Algorithm**: HS256  
**Issuer**: vubank-login-service

## Login Gateway Service (Port 8000)

### Required Headers
All requests to the Login Gateway must include these headers:

```http
Origin: http://localhost:3001
X-Requested-With: XMLHttpRequest
X-Api-Client: web-portal
Content-Type: application/json
```

### Authentication Endpoints

#### POST /api/login
Authenticate user and obtain JWT token.

**Request:**
```http
POST /api/login
Content-Type: application/json
Origin: http://localhost:3001
X-Requested-With: XMLHttpRequest
X-Api-Client: web-portal

{
  "username": "johndoe",
  "password": "password123",
  "force_login": false
}
```

**Request Body:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| username | string | ✅ | User's login username |
| password | string | ✅ | User's password |
| force_login | boolean | ❌ | Force login if session conflict exists |

**Success Response (200):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": "1",
    "username": "johndoe",
    "roles": ["retail"]
  }
}
```

**Session Conflict Response (409):**
```json
{
  "session_conflict": true,
  "existing_session": {
    "created_at": "2024-01-15T10:30:00.000Z",
    "ip_address": "192.168.1.100",
    "user_agent": "Mozilla/5.0..."
  }
}
```

**Error Responses:**

| Status | Error Code | Description |
|--------|------------|-------------|
| 400 | invalid_request | Invalid request body format |
| 400 | invalid_headers | Missing or invalid required headers |
| 401 | invalid_credentials | Invalid username or password |
| 403 | insufficient_permissions | User lacks banking roles |
| 409 | session_conflict | Active session exists (requires force_login) |
| 500 | auth_service_error | Authentication service unavailable |
| 500 | token_generation_error | Failed to generate JWT token |

**Example Error Response:**
```json
{
  "error": "invalid_credentials",
  "message": "Invalid username or password"
}
```

#### GET /api/health
Check service health status.

**Request:**
```http
GET /api/health
```

**Success Response (200):**
```json
{
  "status": "healthy",
  "services": {
    "auth_service": true
  },
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

**Degraded Response (503):**
```json
{
  "status": "degraded",
  "services": {
    "auth_service": false
  },
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

## Authentication Service (Port 8001) - Internal

### Credential Verification

#### POST /verify
Verify user credentials and manage sessions.

**Request:**
```json
{
  "username": "johndoe",
  "password": "password123",
  "force_login": false
}
```

**Headers:**
```http
X-Request-ID: 550e8400-e29b-41d4-a716-446655440000
X-Forwarded-For: 192.168.1.100
User-Agent: Mozilla/5.0...
```

**Success Response (200):**
```json
{
  "ok": true,
  "userId": "1",
  "roles": ["retail"],
  "session_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Session Conflict Response (200):**
```json
{
  "ok": false,
  "session_conflict": true,
  "existing_session": {
    "created_at": "2024-01-15T10:30:00.000Z",
    "ip_address": "192.168.1.100",
    "user_agent": "Mozilla/5.0..."
  }
}
```

**Failed Authentication (200):**
```json
{
  "ok": false
}
```

### Session Management

#### POST /create-session
Create active session record after successful authentication.

**Request:**
```json
{
  "user_id": 1,
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "jwt_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "ip_address": "192.168.1.100",
  "user_agent": "Mozilla/5.0..."
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Session created successfully"
}
```

#### POST /validate-session
Validate active session and JWT token match.

**Request:**
```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "jwt_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Valid Session Response (200):**
```json
{
  "valid": true,
  "user_id": 1
}
```

**Invalid Session Response (200):**
```json
{
  "valid": false,
  "reason": "session_expired"
}
```

**Possible Reasons:**
- `session_not_found`
- `session_terminated` 
- `session_expired`
- `validation_error`

#### GET /health
Authentication service health check.

**Response:**
```json
{
  "status": "healthy",
  "database": "connected"
}
```

## Accounts Service (Port 8002) - Internal

### JWT Authentication Required
All requests must include valid JWT token:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Origin: http://localhost:3001
X-Requested-With: XMLHttpRequest
X-Api-Client: web-portal
```

### Account Data Endpoints

#### GET /internal/accounts
Retrieve user's accounts and recent transactions.

**Request:**
```http
GET /internal/accounts
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Origin: http://localhost:3001
X-Requested-With: XMLHttpRequest
X-Api-Client: web-portal
```

**Success Response (200):**
```json
{
  "userId": "1",
  "accounts": [
    {
      "id": 1,
      "accountNumber": "1001234567890",
      "accountName": "John Doe - Savings",
      "accountType": "savings",
      "balance": 25000.50,
      "currency": "USD",
      "status": "active"
    },
    {
      "id": 2,
      "accountNumber": "1001234567891", 
      "accountName": "John Doe - Checking",
      "accountType": "checking",
      "balance": 5500.75,
      "currency": "USD",
      "status": "active"
    }
  ],
  "recentTransactions": [
    {
      "id": 1,
      "transactionType": "credit",
      "amount": 1000.00,
      "description": "Salary Deposit",
      "referenceNumber": "SAL001",
      "transactionDate": "2024-01-15T10:30:00Z",
      "balanceAfter": 25000.50,
      "status": "completed"
    },
    {
      "id": 2,
      "transactionType": "debit",
      "amount": -200.00,
      "description": "ATM Withdrawal",
      "referenceNumber": "ATM001", 
      "transactionDate": "2024-01-14T15:45:00Z",
      "balanceAfter": 24800.50,
      "status": "completed"
    }
  ]
}
```

**Account Object Fields:**
| Field | Type | Description |
|-------|------|-------------|
| id | integer | Unique account identifier |
| accountNumber | string | 13-digit account number |
| accountName | string | Display name for account |
| accountType | string | savings, checking, business |
| balance | number | Current account balance |
| currency | string | 3-letter currency code |
| status | string | active, inactive, closed |

**Transaction Object Fields:**
| Field | Type | Description |
|-------|------|-------------|
| id | integer | Unique transaction identifier |
| transactionType | string | credit or debit |
| amount | number | Transaction amount (negative for debits) |
| description | string | Transaction description |
| referenceNumber | string | Unique reference number |
| transactionDate | string | ISO 8601 timestamp |
| balanceAfter | number | Account balance after transaction |
| status | string | completed, pending, failed |

**Error Responses:**

| Status | Error Code | Description |
|--------|------------|-------------|
| 401 | missing_token | Authorization header missing |
| 401 | invalid_token_format | Bearer token format invalid |
| 401 | invalid_token | JWT token invalid or expired |
| 401 | invalid_claims | Token claims malformed |
| 403 | insufficient_permissions | User lacks required roles |
| 500 | database_error | Database query failed |

#### GET /health
Accounts service health check.

**Response (200):**
```json
{
  "status": "healthy",
  "database": true,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

**Unhealthy Response (503):**
```json
{
  "status": "unhealthy", 
  "database": false,
  "error": "connection refused",
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

## PDF Receipt Service (Port 8003)

### JWT Authentication Required
All requests must include valid JWT token or can be accessed directly for testing:

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
Origin: http://localhost:3001
```

### PDF Generation Endpoints

#### POST /api/pdf/generate-receipt
Generate professional PDF receipt for banking transactions.

**Request:**
```http
POST /api/pdf/generate-receipt
Content-Type: application/json
Origin: http://localhost:3001

{
  "transaction": {
    "transactionId": "TXN202501150001",
    "transactionDate": "2025-01-15T10:30:00Z",
    "amount": 1500.00,
    "currency": "USD",
    "type": "Fund Transfer",
    "description": "Transfer to John Smith",
    "referenceNumber": "REF001234567890"
  },
  "fromAccount": {
    "accountNumber": "1001234567890",
    "accountName": "Jane Doe - Savings",
    "accountType": "savings"
  },
  "toAccount": {
    "accountNumber": "1001234567891", 
    "accountName": "John Smith",
    "accountType": "checking"
  },
  "user": {
    "name": "Jane Doe",
    "userId": "janedoe"
  }
}
```

**Request Body Fields:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| transaction.transactionId | string | ✅ | Unique transaction identifier |
| transaction.transactionDate | string | ✅ | ISO 8601 timestamp |
| transaction.amount | number | ✅ | Transaction amount |
| transaction.currency | string | ✅ | 3-letter currency code |
| transaction.type | string | ✅ | Transaction type description |
| transaction.description | string | ✅ | Transaction description |
| transaction.referenceNumber | string | ✅ | Unique reference number |
| fromAccount.accountNumber | string | ✅ | Source account number |
| fromAccount.accountName | string | ✅ | Source account display name |
| fromAccount.accountType | string | ✅ | Source account type |
| toAccount.accountNumber | string | ✅ | Destination account number |
| toAccount.accountName | string | ✅ | Destination account name |
| toAccount.accountType | string | ✅ | Destination account type |
| user.name | string | ✅ | User's display name |
| user.userId | string | ✅ | User's login ID |

**Success Response (200):**
```
Content-Type: application/pdf
Content-Disposition: attachment; filename="transaction_receipt_TXN202501150001.pdf"

[PDF Binary Data]
```

**Error Responses:**

| Status | Error Code | Description |
|--------|------------|-------------|
| 400 | invalid_request | Missing required transaction data |
| 400 | invalid_format | Invalid date format or numeric values |
| 500 | pdf_generation_error | Failed to generate PDF document |
| 500 | server_error | Internal server error |

**Example Error Response:**
```json
{
  "timestamp": "2025-01-15T10:30:00.000Z",
  "status": 400,
  "error": "Bad Request", 
  "message": "Missing required field: transaction.transactionId",
  "path": "/api/pdf/generate-receipt"
}
```

#### GET /api/pdf/health
Check PDF service health status.

**Request:**
```http
GET /api/pdf/health
```

**Success Response (200):**
```json
{
  "status": "healthy",
  "service": "PDF Receipt Generator",
  "version": "1.0.0",
  "timestamp": "2025-01-15T10:30:00.000Z"
}
```

**Unhealthy Response (503):**
```json
{
  "status": "unhealthy",
  "service": "PDF Receipt Generator",
  "error": "iText library initialization failed",
  "timestamp": "2025-01-15T10:30:00.000Z"
}
```

#### GET /actuator/health
Spring Boot actuator health endpoint for comprehensive health monitoring.

**Success Response (200):**
```json
{
  "status": "UP",
  "components": {
    "diskSpace": {
      "status": "UP",
      "details": {
        "total": 250685575168,
        "free": 100685575168,
        "threshold": 10485760
      }
    },
    "ping": {
      "status": "UP"
    }
  }
}
```

### PDF Service Features
- **Professional Layout**: Bank-branded PDF receipts with logo and styling
- **Transaction Details**: Complete transaction information with timestamps
- **Account Information**: Source and destination account details
- **Security Elements**: Unique reference numbers and transaction IDs
- **Download Ready**: PDF optimized for download and printing
- **Cross-Origin Support**: CORS enabled for frontend integration

## Fund Transfer System

The fund transfer functionality is implemented as a complete frontend workflow with simulated backend processing. While the current implementation focuses on client-side validation and user experience, the architecture supports full backend integration.

### Frontend Fund Transfer Endpoints

#### Frontend Processing Flow
The fund transfer system operates through a multi-step frontend process:

1. **Step 1**: Transfer details and account selection
2. **Step 2**: Payee management and selection
3. **Step 3**: Confirmation and PIN verification
4. **Step 4**: Transaction processing (simulated)
5. **Step 5**: Receipt generation via PDF service

### Simulated Transaction Processing

#### POST /api/transactions/transfer (Planned)
**Note**: This endpoint represents the planned backend implementation for actual transaction processing.

**Request Structure:**
```json
{
  "fromAccount": {
    "accountNumber": "1001234567890",
    "accountType": "savings"
  },
  "toAccount": {
    "accountNumber": "1001234567891", 
    "accountType": "checking"
  },
  "amount": 1500.00,
  "currency": "USD",
  "description": "Transfer to John Smith",
  "payee": {
    "id": "payee_001",
    "name": "John Smith",
    "nickname": "John - Checking"
  },
  "pin": "1234",
  "referenceNumber": "REF001234567890"
}
```

**Expected Response (200):**
```json
{
  "transaction": {
    "transactionId": "TXN202501150001",
    "transactionDate": "2025-01-15T10:30:00Z",
    "status": "completed",
    "amount": 1500.00,
    "currency": "USD",
    "type": "Fund Transfer",
    "description": "Transfer to John Smith",
    "referenceNumber": "REF001234567890"
  },
  "fromAccountBalance": 23500.50,
  "toAccountBalance": 7000.75,
  "processingTime": "00:00:03"
}
```

### Frontend Validation Endpoints

#### Client-Side Payee Management
The payee management system includes:

**Payee Search (Frontend)**:
```javascript
// Frontend payee search implementation
const searchPayees = (query) => {
  const mockPayees = [
    {
      id: "payee_001",
      name: "John Smith",
      accountNumber: "1001234567891",
      bankName: "VuBank", 
      accountType: "checking",
      nickname: "John - Checking",
      verified: true
    },
    // Additional mock payees...
  ]
  
  return mockPayees.filter(payee => 
    payee.name.toLowerCase().includes(query.toLowerCase()) ||
    payee.nickname.toLowerCase().includes(query.toLowerCase())
  )
}
```

**Account Validation (Frontend)**:
```javascript
// Frontend account validation
const validateTransfer = (transferData) => {
  const validations = {
    amount: validateAmount(transferData.amount, transferData.fromAccountBalance),
    accounts: validateAccounts(transferData.fromAccount, transferData.toAccount),
    payee: validatePayee(transferData.payee),
    pin: validatePIN(transferData.pin)
  }
  
  return {
    isValid: Object.values(validations).every(Boolean),
    errors: Object.entries(validations)
      .filter(([key, valid]) => !valid)
      .map(([key]) => key)
  }
}
```

### Integration with Existing Services

#### Account Balance Integration
Fund transfers integrate with the existing accounts service:

```javascript
// Frontend integration with accounts service
const getAccountBalances = async () => {
  const response = await fetch('/api/accounts', {
    headers: {
      'Authorization': `Bearer ${localStorage.getItem('authToken')}`,
      'Origin': 'http://localhost:3001',
      'X-Requested-With': 'XMLHttpRequest',
      'X-Api-Client': 'web-portal'
    }
  })
  
  const data = await response.json()
  return data.accounts
}
```

#### PDF Receipt Integration
Transaction receipts are generated via the PDF service:

```javascript
// PDF receipt generation for transfers
const generateTransferReceipt = async (transferData) => {
  const receiptData = {
    transaction: {
      transactionId: transferData.transactionId,
      transactionDate: new Date().toISOString(),
      amount: transferData.amount,
      currency: "USD",
      type: "Fund Transfer", 
      description: transferData.description,
      referenceNumber: transferData.referenceNumber
    },
    fromAccount: transferData.fromAccount,
    toAccount: transferData.toAccount,
    user: transferData.user
  }
  
  const response = await fetch('http://localhost:8003/api/pdf/generate-receipt', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(receiptData)
  })
  
  return response.blob() // PDF file for download
}
```

### Future Backend Implementation

#### Planned Database Schema
```sql
-- Planned tables for full backend implementation
CREATE TABLE payees (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  name VARCHAR(100) NOT NULL,
  account_number VARCHAR(20) NOT NULL,
  bank_name VARCHAR(100) NOT NULL,
  account_type VARCHAR(20) NOT NULL,
  nickname VARCHAR(100),
  verified BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_used TIMESTAMP
);

CREATE TABLE transfers (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  from_account_id INTEGER REFERENCES accounts(id),
  to_account_id INTEGER REFERENCES accounts(id),
  payee_id INTEGER REFERENCES payees(id),
  amount DECIMAL(15,2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'USD',
  description TEXT,
  reference_number VARCHAR(50) UNIQUE,
  transaction_id VARCHAR(50) UNIQUE,
  status VARCHAR(20) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  completed_at TIMESTAMP
);
```

#### Planned API Endpoints
- `POST /api/payees` - Add new payee
- `GET /api/payees` - Get user's payees
- `PUT /api/payees/:id` - Update payee information
- `DELETE /api/payees/:id` - Remove payee
- `POST /api/transfers` - Process fund transfer
- `GET /api/transfers/:id` - Get transfer details
- `GET /api/transfers` - Get transfer history

### Security Considerations

#### Frontend Security
- **PIN Validation**: Client-side PIN format validation
- **Amount Limits**: Maximum transfer amount enforcement
- **Session Validation**: JWT token validation for all operations
- **Input Sanitization**: XSS protection on user inputs

#### Planned Backend Security
- **Database Transactions**: ACID compliance for fund transfers
- **Audit Logging**: Complete transfer audit trail
- **PIN Encryption**: Secure PIN storage and validation
- **Rate Limiting**: Transfer frequency and amount limits
- **Fraud Detection**: Suspicious pattern detection

## Error Handling

### Standard Error Response Format
```json
{
  "error": "error_code",
  "message": "Human readable error message"
}
```

### Common HTTP Status Codes

| Status | Meaning | When Used |
|--------|---------|-----------|
| 200 | OK | Successful request |
| 400 | Bad Request | Invalid input or missing required fields |
| 401 | Unauthorized | Missing, invalid, or expired authentication |
| 403 | Forbidden | Valid auth but insufficient permissions |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Session conflict or resource conflict |
| 500 | Internal Server Error | Server-side error |
| 503 | Service Unavailable | Service health check failed |

### Error Code Reference

#### Authentication Errors
| Code | HTTP Status | Description |
|------|-------------|-------------|
| invalid_request | 400 | Malformed request body |
| invalid_headers | 400 | Missing or invalid headers |
| invalid_credentials | 401 | Wrong username/password |
| insufficient_permissions | 403 | User lacks required roles |
| session_conflict | 409 | Active session exists |
| auth_service_error | 500 | Auth service unavailable |
| token_generation_error | 500 | JWT generation failed |

#### Account Service Errors
| Code | HTTP Status | Description |
|------|-------------|-------------|
| missing_token | 401 | Authorization header missing |
| invalid_token_format | 401 | Bearer token format wrong |
| invalid_token | 401 | JWT invalid or expired |
| invalid_claims | 401 | Token claims malformed |
| database_error | 500 | Database operation failed |

## Rate Limiting

### Current Implementation
- No rate limiting implemented in development
- Production deployment should implement:
  - Login attempts: 5 per minute per IP
  - API requests: 100 per minute per user
  - Health checks: No limits

### Recommended Headers
```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640995200
```

## CORS Configuration

### Allowed Origins
- Development: `http://localhost:3001`, `http://localhost:3000`
- Production: `https://banking.vubank.com`

### Allowed Headers
```
Origin, X-Requested-With, Content-Type, Accept, Authorization, X-Api-Client, X-Request-ID
```

### Allowed Methods
```
GET, POST, PUT, DELETE, OPTIONS
```

## Request/Response Examples

### Complete Login Flow

1. **Initial Login Request:**
```bash
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost:3001" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "X-Api-Client: web-portal" \
  -d '{
    "username": "johndoe",
    "password": "password123"
  }'
```

2. **Session Conflict Response:**
```json
{
  "session_conflict": true,
  "existing_session": {
    "created_at": "2024-01-15T09:30:00.000Z",
    "ip_address": "192.168.1.50",
    "user_agent": "Mozilla/5.0..."
  }
}
```

3. **Force Login Request:**
```bash
curl -X POST http://localhost:8000/api/login \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost:3001" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "X-Api-Client: web-portal" \
  -d '{
    "username": "johndoe",
    "password": "password123",
    "force_login": true
  }'
```

4. **Successful Login Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyX2lkIjoiMSIsInJvbGVzIjpbInJldGFpbCJdLCJleHAiOjE2NDA5OTUyMDAsImlhdCI6MTY0MDk5MTYwMCwiaXNzIjoidnViYW5rLWxvZ2luLXNlcnZpY2UifQ.signature",
  "user": {
    "id": "1", 
    "username": "johndoe",
    "roles": ["retail"]
  }
}
```

5. **Fetch Account Data:**
```bash
curl -X GET http://localhost:8002/internal/accounts \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." \
  -H "Origin: http://localhost:3001" \
  -H "X-Requested-With: XMLHttpRequest" \
  -H "X-Api-Client: web-portal"
```

6. **Generate PDF Receipt (Optional):**
```bash
curl -X POST http://localhost:8003/api/pdf/generate-receipt \
  -H "Content-Type: application/json" \
  -H "Origin: http://localhost:3001" \
  -d '{
    "transaction": {
      "transactionId": "TXN202501150001",
      "transactionDate": "2025-01-15T10:30:00Z",
      "amount": 1500.00,
      "currency": "USD",
      "type": "Fund Transfer",
      "description": "Transfer to John Smith",
      "referenceNumber": "REF001234567890"
    },
    "fromAccount": {
      "accountNumber": "1001234567890",
      "accountName": "Jane Doe - Savings",
      "accountType": "savings"
    },
    "toAccount": {
      "accountNumber": "1001234567891",
      "accountName": "John Smith", 
      "accountType": "checking"
    },
    "user": {
      "name": "Jane Doe",
      "userId": "janedoe"
    }
  }' \
  --output transaction_receipt.pdf
```

### Test User Credentials

| Username | Password | Roles | Description |
|----------|----------|-------|-------------|
| johndoe | password123 | retail | Retail customer with savings/checking |
| janedoe | password123 | retail | Retail customer with savings account |
| corpuser | password123 | corporate | Corporate customer with business account |

## Security Considerations

### JWT Security
- **Short Expiry**: 15-minute token lifespan reduces exposure
- **Strong Secret**: 256-bit signing key required
- **Claims Validation**: User ID and roles verified on each request
- **No Refresh**: Tokens must be re-obtained after expiry

### Header Validation
- **Origin Verification**: Prevents CSRF attacks
- **API Client Check**: Ensures requests from authorized clients
- **Request Correlation**: Unique IDs for request tracking

### Session Management
- **Single Session**: One active session per user
- **Session Tracking**: Database audit trail
- **IP Validation**: Session bound to originating IP
- **Force Logout**: Ability to terminate conflicting sessions

### Password Security
- **bcrypt Hashing**: Industry-standard with cost factor 12
- **No Plain Storage**: Passwords never stored in plain text
- **Salt Included**: Automatic salt generation prevents rainbow attacks

## Monitoring and Logging

### Request Correlation
Every request receives a unique correlation ID:
```http
X-Request-ID: 550e8400-e29b-41d4-a716-446655440000
```

### Audit Logging
All authentication attempts logged with:
- User ID and username
- IP address and user agent
- Success/failure status
- Failure reasons
- Request correlation ID

### Health Monitoring
- Service health endpoints for uptime monitoring
- Database connectivity checks
- Dependency service validation

## Development Tools

### Postman Collection
Import the API collection for testing:
```json
{
  "info": {
    "name": "VuBank API",
    "version": "1.0.0"
  },
  "item": [
    {
      "name": "Login",
      "request": {
        "method": "POST",
        "url": "{{base_url}}/api/login",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          },
          {
            "key": "Origin", 
            "value": "http://localhost:3001"
          },
          {
            "key": "X-Requested-With",
            "value": "XMLHttpRequest"
          },
          {
            "key": "X-Api-Client",
            "value": "web-portal"
          }
        ],
        "body": {
          "raw": "{\n  \"username\": \"johndoe\",\n  \"password\": \"password123\"\n}"
        }
      }
    }
  ],
  "variable": [
    {
      "key": "base_url",
      "value": "http://localhost:8000"
    }
  ]
}
```

### Environment Variables
```bash
# Development
export PUBLIC_API_PORT=8000
export AUTH_SERVICE_URL=http://localhost:8001
export ACCOUNTS_SERVICE_URL=http://localhost:8002
export JWT_SECRET=your-super-secret-jwt-key
export API_CLIENT=web-portal

# Database
export DB_HOST=localhost
export DB_PORT=5432
export DB_USER=vubank_user
export DB_PASSWORD=vubank_pass
export DB_NAME=vubank_db
```