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