# VuBank NextGen Banking Platform - Data Flows and User Journeys

## User Authentication Flow

### Login Process
```mermaid
sequenceDiagram
    participant U as User/Frontend
    participant GW as Go Gateway :8000
    participant AUTH as Python Auth :8001
    participant DB as PostgreSQL :5432

    U->>GW: POST /api/login {username, password}
    Note over GW: Validate headers<br/>(Origin, X-Requested-With, X-Api-Client)
    
    GW->>AUTH: POST /verify {username, password}
    AUTH->>DB: SELECT user with roles WHERE username
    DB-->>AUTH: User data + roles
    
    Note over AUTH: Verify password with bcrypt
    Note over AUTH: Check user is_active status
    
    AUTH->>DB: Check existing active sessions
    DB-->>AUTH: Session data (if exists)
    
    alt Session conflict detected
        AUTH-->>GW: 409 Conflict + existing session info
        GW-->>U: Session conflict dialog
        
        U->>GW: POST /api/login {force_login: true}
        GW->>AUTH: POST /verify {force_login: true}
        AUTH->>DB: Terminate existing sessions
        Note over AUTH: Generate new session_id
    else No session conflict
        Note over AUTH: Generate new session_id
    end
    
    AUTH-->>GW: 200 OK {userId, roles, session_id}
    
    Note over GW: Generate JWT token<br/>(15-minute expiry)
    
    GW->>AUTH: POST /create-session {user_id, session_id, jwt_hash}
    AUTH->>DB: INSERT active_sessions
    AUTH->>DB: INSERT login_requests (audit)
    
    GW-->>U: 200 OK {token, user}
    Note over U: Store JWT in localStorage
```

### Session Management Flow
```mermaid
flowchart TD
    A[User Login Request] --> B{Existing Session?}
    
    B -->|No| C[Create New Session]
    B -->|Yes| D{Force Login?}
    
    D -->|No| E[Show Session Conflict Dialog]
    D -->|Yes| F[Terminate Existing Session]
    
    E --> G[User Choice]
    G -->|Cancel| H[Return to Login]
    G -->|Continue| F
    
    F --> I[Create New Session]
    C --> J[Generate JWT Token]
    I --> J
    
    J --> K[Store Session in DB]
    K --> L[Return Success Response]
```

## Account Data Retrieval Flow

### Dashboard Data Loading
```mermaid
sequenceDiagram
    participant U as User/Frontend
    participant GW as Go Gateway :8000
    participant ACC as Accounts Service :8002
    participant DB as PostgreSQL :5432

    Note over U: User logged in with JWT token
    
    U->>ACC: GET /internal/accounts
    Note over U: Headers: Authorization: Bearer {jwt}<br/>Origin, X-Requested-With, X-Api-Client
    
    Note over ACC: Validate JWT token
    Note over ACC: Extract user_id from claims
    Note over ACC: Check user roles (retail/corporate)
    
    ACC->>DB: SELECT accounts WHERE user_id AND status='active'
    DB-->>ACC: Account records
    
    ACC->>DB: SELECT recent transactions<br/>JOIN accounts ON user_id LIMIT 20
    DB-->>ACC: Transaction records
    
    Note over ACC: Transform data for frontend
    
    ACC-->>U: 200 OK {accounts, recentTransactions}
    
    Note over U: Update dashboard state<br/>Display account balances<br/>Show recent transactions
```

### Error Handling in Data Flow
```mermaid
flowchart TD
    A[Request with JWT] --> B{JWT Valid?}
    
    B -->|No| C[401 Unauthorized]
    B -->|Yes| D{User Has Required Role?}
    
    D -->|No| E[403 Forbidden]
    D -->|Yes| F{Database Available?}
    
    F -->|No| G[500 Internal Server Error]
    F -->|Yes| H[Execute Query]
    
    H --> I{Query Successful?}
    I -->|No| J[500 Database Error]
    I -->|Yes| K[Return Data]
    
    C --> L[Frontend: Clear Token & Redirect to Login]
    E --> M[Frontend: Show Permission Error]
    G --> N[Frontend: Show Service Unavailable]
    J --> O[Frontend: Show Data Loading Error]
```

## Service Communication Patterns

### Inter-Service Request Flow
```mermaid
graph LR
    subgraph "Frontend :3001"
        F1[React App]
    end
    
    subgraph "API Gateway :8000"
        G1[Go Login Service]
        G2[Header Validation]
        G3[JWT Generation]
        G4[Request Routing]
    end
    
    subgraph "Auth Service :8001"
        A1[Python FastAPI]
        A2[Credential Verification]
        A3[Session Management]
        A4[Audit Logging]
    end
    
    subgraph "Accounts Service :8002"
        AC1[Go Accounts Service]
        AC2[JWT Validation]
        AC3[Account Queries]
        AC4[Transaction Queries]
    end
    
    subgraph "Database :5432"
        D1[PostgreSQL]
        D2[Users & Auth]
        D3[Accounts & Transactions]
        D4[Sessions & Audit]
    end
    
    F1 --> G1
    G1 --> G2
    G2 --> A1
    A1 --> A2
    A2 --> D2
    A3 --> D4
    
    G1 --> G3
    G3 --> F1
    
    F1 --> AC1
    AC1 --> AC2
    AC2 --> AC3
    AC3 --> D3
    AC4 --> D3
```

## Data Transformation Flow

### User Login Data Pipeline
```
Frontend Input → Gateway Validation → Auth Processing → Database Storage
     ↓                    ↓                    ↓                 ↓
{username,         {validated         {bcrypt         {audit_log,
 password}          headers,           verification,    active_session,
                   correlation_id}     role_check}      user_update}
```

### Account Data Pipeline
```
Database Query → Service Processing → API Response → Frontend Display
      ↓                 ↓                  ↓              ↓
{raw_account_     {structured        {json_response}   {ui_components,
 transaction_      data_objects,                        formatted_currency,
 data}            security_checks}                      date_formatting}
```

## User Journey Flows

### First-Time Login Journey
1. **Landing Page**
   - User enters credentials
   - Frontend validates input format
   - Displays loading state during authentication

2. **Authentication Process**
   - Headers validated by gateway
   - Credentials verified by auth service
   - JWT token generated and returned

3. **Dashboard Access**
   - Token stored in localStorage
   - Dashboard component mounts
   - Account data fetched automatically
   - Real-time balance and transaction display

## Fund Transfer Workflow

### Complete Fund Transfer Journey
```mermaid
sequenceDiagram
    participant U as User/Frontend
    participant FT as Fund Transfer Page
    participant API as Accounts Service :8002
    participant PDF as PDF Service :8003

    U->>FT: Navigate to /FundTransfer.html
    FT->>FT: Load user session data
    FT->>API: GET account balances (JWT)
    API-->>FT: Account list with balances
    
    Note over FT: Step 1: Transfer Details
    U->>FT: Enter amount and select accounts
    FT->>FT: Validate amount vs balance
    FT->>FT: Show payee search/selection
    
    Note over FT: Step 2: Payee Management  
    U->>FT: Search or add new payee
    FT->>FT: Display payee suggestions
    U->>FT: Select/confirm payee details
    FT->>FT: Validate transfer details
    
    Note over FT: Step 3: Confirmation
    FT->>FT: Display transfer summary
    U->>FT: Review and confirm details
    U->>FT: Enter 4-digit PIN
    FT->>FT: Validate PIN format
    
    Note over FT: Step 4: Processing
    FT->>API: POST transfer request (simulated)
    API-->>FT: Transaction confirmation
    FT->>FT: Display success screen
    
    Note over FT: Step 5: Receipt Generation
    U->>FT: Click "Download Receipt"
    FT->>PDF: POST /api/pdf/generate-receipt
    PDF-->>FT: PDF file download
    FT-->>U: Browser downloads PDF receipt
```

### Multi-Step Transfer Process

#### Step 1: Transfer Details & Account Selection
**Purpose**: Capture basic transfer information and validate user inputs
**Components**:
- **Amount Input**: Real-time validation against account balance
- **Source Account**: Dropdown with current balances displayed
- **Currency**: Fixed to USD (extensible for multi-currency)
- **Transfer Type**: Fund Transfer (default)

**Validations**:
```javascript
// Amount validation
if (amount <= 0) return "Amount must be greater than zero"
if (amount > accountBalance) return "Insufficient balance"
if (!isValidNumber(amount)) return "Invalid amount format"

// Account validation  
if (fromAccount === toAccount) return "Cannot transfer to same account"
if (!fromAccount || !toAccount) return "Please select accounts"
```

#### Step 2: Payee Management & Selection
**Purpose**: Manage transfer recipients with search and add functionality
**Features**:
- **Payee Search**: Real-time search with autocomplete suggestions
- **Add New Payee**: Modal form for new payee registration
- **Payee Validation**: Account number format and bank validation
- **Recent Payees**: Quick access to frequently used recipients

**Payee Data Structure**:
```javascript
const payee = {
  id: "payee_001",
  name: "John Smith", 
  accountNumber: "1001234567891",
  bankName: "VuBank",
  accountType: "checking",
  nickname: "John - Checking",
  verified: true,
  lastUsed: "2025-01-15T10:30:00Z"
}
```

#### Step 3: Confirmation & PIN Verification
**Purpose**: Final review and secure authorization
**Components**:
- **Transfer Summary**: Complete transfer details review
- **PIN Entry**: 4-digit security PIN with masked input
- **Terms Acceptance**: Transfer terms and conditions
- **Final Validation**: All transfer parameters confirmed

**Security Features**:
```javascript
// PIN validation
const validatePIN = (pin) => {
  if (pin.length !== 4) return false
  if (!/^\d{4}$/.test(pin)) return false
  // In production: validate against encrypted stored PIN
  return pin === "1234" // Demo PIN
}
```

#### Step 4: Transaction Processing
**Purpose**: Execute transfer and provide confirmation
**Process**:
1. **Pre-validation**: Final balance and account checks
2. **Transaction Simulation**: Realistic processing time (2-3 seconds)
3. **Transaction ID Generation**: Unique reference number
4. **Balance Updates**: Real-time account balance synchronization
5. **Confirmation Display**: Success message with transaction details

#### Step 5: Receipt Generation & Download
**Purpose**: Provide professional transaction documentation
**Features**:
- **PDF Generation**: Professional bank-branded receipt
- **Transaction Details**: Complete transfer information
- **Download Prompt**: Automatic browser download initiation
- **Receipt Naming**: Dynamic filename with transaction ID

### Frontend State Management

#### Multi-Step Navigation
```javascript
class FundTransferManager {
  constructor() {
    this.currentStep = 1
    this.maxSteps = 5
    this.transferData = {}
    this.validationErrors = {}
  }
  
  goToStep(step) {
    if (step > this.currentStep && !this.validateCurrentStep()) {
      return false // Prevent forward navigation with errors
    }
    this.currentStep = step
    this.updateUI()
  }
  
  validateStep(stepNumber) {
    switch(stepNumber) {
      case 1: return this.validateTransferDetails()
      case 2: return this.validatePayeeSelection() 
      case 3: return this.validateConfirmation()
      case 4: return this.processTransfer()
    }
  }
}
```

#### Data Persistence
- **Session Storage**: Transfer data persisted across page reloads
- **Form Recovery**: Auto-recovery of partially completed transfers
- **Validation State**: Real-time validation with user feedback
- **Progress Indicators**: Visual progress through transfer steps

### Error Handling & User Experience

#### Validation Errors
```javascript
const errorTypes = {
  INSUFFICIENT_BALANCE: "Insufficient account balance",
  INVALID_AMOUNT: "Please enter a valid amount",
  PAYEE_REQUIRED: "Please select a payee",
  INVALID_PIN: "Please enter your 4-digit PIN",
  ACCOUNT_SELECTION: "Please select different source and destination accounts"
}
```

#### User Feedback
- **Real-time Validation**: Immediate feedback on form inputs  
- **Progress Indicators**: Clear step-by-step progress display
- **Loading States**: Smooth loading animations during processing
- **Success Confirmation**: Clear confirmation of completed transfers
- **Error Recovery**: Helpful error messages with resolution steps

### Session Conflict Resolution Journey
1. **Conflict Detection**
   - User attempts login with existing session
   - Auth service detects active session
   - Returns conflict information

2. **User Decision**
   - Modal dialog displays existing session details
   - User can cancel or force login
   - Clear explanation of consequences

3. **Resolution**
   - If forced: Previous session terminated
   - New session created with audit trail
   - User successfully logged in

### Error Recovery Journey
1. **Error Detection**
   - Service unavailable or network error
   - JWT token expired during usage
   - Database connection failure

2. **User Notification**
   - Clear error messages displayed
   - Retry buttons where appropriate
   - Graceful degradation of features

3. **Recovery Actions**
   - Automatic token refresh attempt
   - Service health check before retry
   - Fallback to cached data when possible

## Request/Response Data Structures

### Login Request Flow
```json
// Frontend → Gateway
{
  "username": "johndoe",
  "password": "password123",
  "force_login": false
}

// Gateway → Auth Service
{
  "username": "johndoe", 
  "password": "password123",
  "force_login": false
}

// Auth Service → Database
SELECT u.id, u.username, u.password_hash, u.is_active,
       array_agg(r.name) as roles
FROM users u
LEFT JOIN user_roles ur ON u.id = ur.user_id  
LEFT JOIN roles r ON ur.role_id = r.id
WHERE u.username = $1
```

### Account Data Flow
```json
// Frontend Request Headers
{
  "Authorization": "Bearer eyJhbGciOiJIUzI1NiIs...",
  "Origin": "http://localhost:3001",
  "X-Requested-With": "XMLHttpRequest",
  "X-Api-Client": "web-portal"
}

// Database Response
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
      "balanceAfter": 25000.50
    }
  ]
}
```

## Performance Considerations

### Database Query Optimization
```sql
-- Optimized account retrieval with single query
SELECT 
    a.id, a.account_number, a.account_name, a.account_type,
    a.balance, a.currency, a.status,
    t.id as transaction_id, t.transaction_type, t.amount,
    t.description, t.reference_number, t.transaction_date
FROM accounts a
LEFT JOIN LATERAL (
    SELECT * FROM transactions 
    WHERE account_id = a.id 
    ORDER BY transaction_date DESC 
    LIMIT 5
) t ON true
WHERE a.user_id = $1 AND a.status = 'active'
ORDER BY a.created_at DESC;
```

### Frontend State Management
```javascript
// Optimized state updates to prevent unnecessary re-renders
const Dashboard = ({ user, onLogout }) => {
  const [accounts, setAccounts] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(true);
  
  // Single API call for all dashboard data
  useEffect(() => {
    const fetchDashboardData = async () => {
      try {
        const response = await fetchAccountsAndTransactions();
        setAccounts(response.accounts);
        setTransactions(response.recentTransactions);
      } finally {
        setLoading(false);
      }
    };
    
    fetchDashboardData();
  }, []); // Empty dependency array - only fetch once
};
```

### Service Communication Optimization
- **Connection Pooling**: Database connections reused across requests
- **Request Correlation**: Unique IDs for distributed request tracing
- **Circuit Breaker**: Fail fast when dependent services are down
- **Caching Strategy**: JWT validation results cached for duration of token

## PDF Receipt Generation Flow

### Transaction Receipt Generation
```mermaid
sequenceDiagram
    participant U as User/Frontend
    participant PDF as Java PDF Service :8003
    participant ITXT as iText PDF Engine

    U->>PDF: POST /api/pdf/generate-receipt
    Note over U: Transaction data payload:<br/>{transaction, fromAccount,<br/>toAccount, user}
    
    PDF->>PDF: Validate request payload
    Note over PDF: Check required fields:<br/>- Transaction ID, amount, date<br/>- Account details<br/>- User information
    
    PDF->>ITXT: Initialize PDF document
    ITXT-->>PDF: PDF document object
    
    PDF->>ITXT: Add bank header & logo
    PDF->>ITXT: Add transaction details table
    PDF->>ITXT: Add account information
    PDF->>ITXT: Add reference numbers
    PDF->>ITXT: Add timestamp & footer
    
    ITXT-->>PDF: Complete PDF document
    PDF->>PDF: Set response headers
    Note over PDF: Content-Type: application/pdf<br/>Content-Disposition: attachment
    
    PDF-->>U: PDF file download
    Note over U: Browser downloads:<br/>transaction_receipt_[ID].pdf
```

### Error Handling in PDF Generation
```
Request Validation:
├── Missing transaction ID → 400 Bad Request
├── Invalid date format → 400 Bad Request  
├── Missing account data → 400 Bad Request
└── PDF generation failure → 500 Internal Server Error
```

### Integration Points
- **Frontend Integration**: Direct API calls from fund transfer page
- **CORS Configuration**: Enabled for localhost:3001 origin
- **File Naming**: Dynamic filename based on transaction ID
- **Error Responses**: JSON error format matching other services
- **Health Monitoring**: Dedicated health check endpoint