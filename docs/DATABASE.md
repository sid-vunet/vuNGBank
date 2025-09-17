# VuBank NextGen Banking Platform - Database Documentation

## Overview

The VuBank database uses PostgreSQL 15 as the primary data store, designed for a banking simulation environment with comprehensive audit trails and security features. The schema supports user management, account operations, transaction tracking, and session management.

## Database Configuration

### Connection Details
```yaml
Development Environment:
  Host: localhost
  Port: 5432
  Database: vubank_db
  Username: vubank_user
  Password: vubank_pass
  SSL Mode: disable

Production Environment:
  Host: postgres-primary.internal
  Port: 5432
  Database: vubank_production
  Username: vubank_prod_user
  Password: [ENVIRONMENT_VARIABLE]
  SSL Mode: require
```

### Connection String Format
```
postgresql://vubank_user:vubank_pass@localhost:5432/vubank_db?sslmode=disable
```

## Schema Overview

### Entity Relationship Diagram
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    roles    │◄───┤ user_roles  ├───►│    users    │
│             │    │             │    │             │
│ - id        │    │ - user_id   │    │ - id        │
│ - name      │    │ - role_id   │    │ - username  │
│ - description│   │ - assigned_at│   │ - email     │
└─────────────┘    └─────────────┘    │ - password_hash│
                                      │ - is_active │
                                      └─────┬───────┘
                                            │
                                            │ 1:N
                                            ▼
                        ┌─────────────┐    ┌─────────────┐
                        │ accounts    │◄───┤transactions │
                        │             │    │             │
                        │ - id        │    │ - id        │
                        │ - user_id   │    │ - account_id│
                        │ - account_number│ │ - transaction_type│
                        │ - account_name  │ │ - amount    │
                        │ - account_type  │ │ - description│
                        │ - balance   │    │ - reference_number│
                        │ - currency  │    │ - transaction_date│
                        │ - status    │    │ - balance_after│
                        └─────────────┘    │ - status    │
                                          └─────────────┘

┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│active_sessions│   │login_requests│   │    users    │
│             │    │             │    │             │
│ - user_id   ├───►│ - user_id   ├───►│ - id        │
│ - session_id│    │ - username  │    │ - username  │
│ - jwt_token_hash│ │ - ip_address│    └─────────────┘
│ - ip_address│    │ - user_agent│
│ - user_agent│    │ - success   │
│ - expires_at│    │ - failure_reason│
│ - is_active │    │ - attempted_at│
└─────────────┘    └─────────────┘
```

## Table Definitions

### 1. roles
System roles for user authorization.

```sql
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Columns:**
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | Unique role identifier |
| name | VARCHAR(50) | UNIQUE, NOT NULL | Role name (retail, corporate, admin) |
| description | TEXT | | Role description |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Role creation date |

**Default Data:**
| id | name | description |
|----|------|-------------|
| 1 | retail | Retail banking customer |
| 2 | corporate | Corporate banking customer |
| 3 | admin | System administrator |

### 2. users
User authentication and profile information.

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Columns:**
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | Unique user identifier |
| username | VARCHAR(100) | UNIQUE, NOT NULL | Login username |
| email | VARCHAR(255) | UNIQUE, NOT NULL | User email address |
| password_hash | VARCHAR(255) | NOT NULL | bcrypt hashed password |
| is_active | BOOLEAN | DEFAULT TRUE | Account active status |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Account creation date |
| updated_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Last modification date |

**Password Hashing:**
- Algorithm: bcrypt
- Cost Factor: 12
- Example Hash: `$2b$12$yhkx62UhXhfSst8XoYn6UOLtW7OfSgqoR6VyXpzH.npKs.pSK/tPa`

**Test Users:**
| username | email | roles | password (plain) |
|----------|-------|-------|------------------|
| johndoe | john.doe@example.com | retail | password123 |
| janedoe | jane.doe@example.com | retail | password123 |
| corpuser | corporate@vubank.com | corporate | password123 |

### 3. user_roles
Many-to-many mapping between users and roles.

```sql
CREATE TABLE user_roles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, role_id)
);
```

**Columns:**
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | Unique assignment identifier |
| user_id | INTEGER | FOREIGN KEY, NOT NULL | Reference to users.id |
| role_id | INTEGER | FOREIGN KEY, NOT NULL | Reference to roles.id |
| assigned_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Role assignment date |

**Constraints:**
- UNIQUE(user_id, role_id) - Prevents duplicate role assignments
- CASCADE DELETE - Removes assignments when user/role deleted

### 4. accounts
User bank accounts with balances and metadata.

```sql
CREATE TABLE accounts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    account_number VARCHAR(20) UNIQUE NOT NULL,
    account_name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL DEFAULT 'savings',
    balance DECIMAL(15,2) DEFAULT 0.00,
    currency VARCHAR(3) DEFAULT 'USD',
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Columns:**
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | Unique account identifier |
| user_id | INTEGER | FOREIGN KEY, NOT NULL | Reference to users.id |
| account_number | VARCHAR(20) | UNIQUE, NOT NULL | 13-digit account number |
| account_name | VARCHAR(255) | NOT NULL | Display name for account |
| account_type | VARCHAR(50) | DEFAULT 'savings' | Account type |
| balance | DECIMAL(15,2) | DEFAULT 0.00 | Current account balance |
| currency | VARCHAR(3) | DEFAULT 'USD' | 3-letter currency code |
| status | VARCHAR(20) | DEFAULT 'active' | Account status |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Account creation date |
| updated_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Last modification date |

**Account Types:**
- `savings` - Savings account
- `checking` - Checking account
- `business` - Business account
- `loan` - Loan account
- `credit` - Credit card account

**Account Statuses:**
- `active` - Normal operating status
- `inactive` - Temporarily disabled
- `closed` - Permanently closed
- `frozen` - Frozen due to security/legal issues

**Account Number Format:**
- Pattern: `[1-2][0-9]{12}` (13 digits)
- Personal accounts: Start with `1` (e.g., `1001234567890`)
- Business accounts: Start with `2` (e.g., `2001234567890`)

### 5. transactions
Transaction history for all accounts.

```sql
CREATE TABLE transactions (
    id SERIAL PRIMARY KEY,
    account_id INTEGER REFERENCES accounts(id) ON DELETE CASCADE,
    transaction_type VARCHAR(50) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    description TEXT,
    reference_number VARCHAR(100),
    transaction_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    balance_after DECIMAL(15,2),
    status VARCHAR(20) DEFAULT 'completed'
);
```

**Columns:**
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | Unique transaction identifier |
| account_id | INTEGER | FOREIGN KEY, NOT NULL | Reference to accounts.id |
| transaction_type | VARCHAR(50) | NOT NULL | Type of transaction |
| amount | DECIMAL(15,2) | NOT NULL | Transaction amount |
| description | TEXT | | Transaction description |
| reference_number | VARCHAR(100) | | Unique reference number |
| transaction_date | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Transaction timestamp |
| balance_after | DECIMAL(15,2) | | Account balance after transaction |
| status | VARCHAR(20) | DEFAULT 'completed' | Transaction status |

**Transaction Types:**
- `credit` - Money into account (deposits, transfers in)
- `debit` - Money out of account (withdrawals, transfers out)
- `fee` - Bank fees or charges
- `interest` - Interest earned or charged
- `adjustment` - Manual balance adjustments

**Transaction Statuses:**
- `pending` - Transaction initiated but not processed
- `completed` - Successfully processed
- `failed` - Transaction failed to process
- `cancelled` - Transaction cancelled by user/system
- `reversed` - Transaction reversed/refunded

**Amount Conventions:**
- Credit transactions: Positive amounts
- Debit transactions: Negative amounts in API responses
- Database stores all amounts as entered (positive for credits, negative for debits)

### 6. login_requests
Audit log for all authentication attempts.

```sql
CREATE TABLE login_requests (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
    username VARCHAR(100) NOT NULL,
    ip_address INET,
    user_agent TEXT,
    success BOOLEAN NOT NULL,
    failure_reason VARCHAR(255),
    request_id VARCHAR(100),
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Columns:**
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | Unique log entry identifier |
| user_id | INTEGER | FOREIGN KEY | Reference to users.id (nullable) |
| username | VARCHAR(100) | NOT NULL | Username attempted |
| ip_address | INET | | Client IP address |
| user_agent | TEXT | | Client user agent string |
| success | BOOLEAN | NOT NULL | Whether login succeeded |
| failure_reason | VARCHAR(255) | | Reason for failed login |
| request_id | VARCHAR(100) | | Request correlation ID |
| attempted_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Login attempt timestamp |

**Failure Reasons:**
- `user_not_found` - Username doesn't exist
- `user_inactive` - User account is disabled
- `invalid_password` - Wrong password provided
- `session_conflict` - Active session exists
- `system_error` - Internal system error
- `insufficient_permissions` - User lacks required roles

**IP Address Handling:**
- Uses PostgreSQL INET type for proper IP validation
- IPv4 and IPv6 addresses supported
- NULL for internal service calls or unknown IPs

### 7. active_sessions
Active user sessions for concurrent login management.

```sql
CREATE TABLE active_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    session_id VARCHAR(255) UNIQUE NOT NULL,
    jwt_token_hash VARCHAR(255) NOT NULL,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    terminated_reason VARCHAR(100),
    terminated_at TIMESTAMP
);
```

**Columns:**
| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | Unique session identifier |
| user_id | INTEGER | FOREIGN KEY, NOT NULL | Reference to users.id |
| session_id | VARCHAR(255) | UNIQUE, NOT NULL | UUID session identifier |
| jwt_token_hash | VARCHAR(255) | NOT NULL | SHA-256 hash of JWT token |
| ip_address | INET | | Session originating IP |
| user_agent | TEXT | | Client user agent |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Session creation time |
| expires_at | TIMESTAMP | NOT NULL | Session expiration time |
| is_active | BOOLEAN | DEFAULT TRUE | Whether session is active |
| terminated_reason | VARCHAR(100) | | Reason for session termination |
| terminated_at | TIMESTAMP | | Session termination time |

**Session Management:**
- **Single Session Policy**: One active session per user
- **Session Duration**: 24 hours from creation
- **JWT Hash Storage**: SHA-256 hash for token validation without storing actual JWT
- **Automatic Cleanup**: Expired sessions marked inactive

**Termination Reasons:**
- `logout` - User initiated logout
- `force_login` - New login terminated old session
- `expired` - Session exceeded expiry time
- `security` - Security-related termination
- `admin` - Administrative termination

## Indexes

### Performance Indexes
```sql
-- User lookup optimization
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

-- Account queries optimization
CREATE INDEX idx_accounts_user_id ON accounts(user_id);
CREATE INDEX idx_accounts_account_number ON accounts(account_number);

-- Transaction queries optimization
CREATE INDEX idx_transactions_account_id ON transactions(account_id);

-- Audit and session indexes
CREATE INDEX idx_login_requests_user_id ON login_requests(user_id);
CREATE INDEX idx_login_requests_attempted_at ON login_requests(attempted_at);
CREATE INDEX idx_active_sessions_user_id ON active_sessions(user_id);
CREATE INDEX idx_active_sessions_session_id ON active_sessions(session_id);
CREATE INDEX idx_active_sessions_expires_at ON active_sessions(expires_at);
CREATE INDEX idx_active_sessions_is_active ON active_sessions(is_active);
```

### Index Usage Patterns

**Authentication Queries:**
- `idx_users_username` - Login username lookup
- `idx_active_sessions_user_id` - Check existing sessions
- `idx_active_sessions_session_id` - Session validation

**Account Data Queries:**
- `idx_accounts_user_id` - User's accounts lookup
- `idx_transactions_account_id` - Account transaction history

**Audit and Monitoring:**
- `idx_login_requests_user_id` - User login history
- `idx_login_requests_attempted_at` - Time-based audit queries
- `idx_active_sessions_expires_at` - Expired session cleanup

## Common Queries

### Authentication Queries

#### User Login Verification
```sql
SELECT 
    u.id, u.username, u.email, u.password_hash, u.is_active,
    COALESCE(array_agg(r.name) FILTER (WHERE r.name IS NOT NULL), ARRAY[]::varchar[]) as roles
FROM users u
LEFT JOIN user_roles ur ON u.id = ur.user_id
LEFT JOIN roles r ON ur.role_id = r.id
WHERE u.username = $1
GROUP BY u.id, u.username, u.email, u.password_hash, u.is_active;
```

#### Check Existing Sessions
```sql
SELECT session_id, created_at, ip_address, user_agent 
FROM active_sessions 
WHERE user_id = $1 AND is_active = TRUE AND expires_at > NOW();
```

#### Create Session Record
```sql
INSERT INTO active_sessions 
(user_id, session_id, jwt_token_hash, ip_address, user_agent, expires_at)
VALUES ($1, $2, $3, $4, $5, $6);
```

### Account Data Queries

#### Get User Accounts
```sql
SELECT id, account_number, account_name, account_type, balance, currency, status
FROM accounts 
WHERE user_id = $1 AND status = 'active'
ORDER BY created_at DESC;
```

#### Get Recent Transactions
```sql
SELECT t.id, t.transaction_type, t.amount, t.description, 
       t.reference_number, t.transaction_date, t.balance_after, t.status
FROM transactions t
JOIN accounts a ON t.account_id = a.id
WHERE a.user_id = $1
ORDER BY t.transaction_date DESC
LIMIT 20;
```

#### Account Balance Summary
```sql
SELECT 
    account_type,
    COUNT(*) as account_count,
    SUM(balance) as total_balance,
    currency
FROM accounts
WHERE user_id = $1 AND status = 'active'
GROUP BY account_type, currency
ORDER BY account_type;
```

### Audit and Monitoring Queries

#### Login Attempt History
```sql
SELECT 
    username, 
    ip_address, 
    success, 
    failure_reason, 
    attempted_at
FROM login_requests
WHERE user_id = $1
ORDER BY attempted_at DESC
LIMIT 50;
```

#### Failed Login Analysis
```sql
SELECT 
    username,
    COUNT(*) as failed_attempts,
    MAX(attempted_at) as last_attempt
FROM login_requests
WHERE success = FALSE 
    AND attempted_at > NOW() - INTERVAL '1 hour'
GROUP BY username
HAVING COUNT(*) >= 5
ORDER BY failed_attempts DESC;
```

#### Active Session Summary
```sql
SELECT 
    u.username,
    s.session_id,
    s.ip_address,
    s.created_at,
    s.expires_at
FROM active_sessions s
JOIN users u ON s.user_id = u.id
WHERE s.is_active = TRUE
ORDER BY s.created_at DESC;
```

## Data Migration and Versioning

### Schema Versioning
```sql
-- Version tracking table
CREATE TABLE schema_migrations (
    version VARCHAR(50) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

-- Current version
INSERT INTO schema_migrations (version, description) VALUES 
('v1.0.0', 'Initial schema with user auth and accounts');
```

### Migration Scripts

#### Example Migration: Add Account Categories
```sql
-- Migration: v1.1.0 - Add account categories
BEGIN;

-- Add category column
ALTER TABLE accounts ADD COLUMN category VARCHAR(50) DEFAULT 'standard';

-- Update existing accounts
UPDATE accounts SET category = 'premium' WHERE balance > 100000;
UPDATE accounts SET category = 'business' WHERE account_type = 'business';

-- Create index
CREATE INDEX idx_accounts_category ON accounts(category);

-- Record migration
INSERT INTO schema_migrations (version, description) VALUES 
('v1.1.0', 'Added account categories');

COMMIT;
```

## Database Maintenance

### Regular Maintenance Tasks

#### Session Cleanup
```sql
-- Mark expired sessions as inactive
UPDATE active_sessions 
SET is_active = FALSE, 
    terminated_reason = 'expired',
    terminated_at = NOW()
WHERE expires_at < NOW() AND is_active = TRUE;
```

#### Audit Log Archival
```sql
-- Archive old login requests (keep 90 days)
DELETE FROM login_requests 
WHERE attempted_at < NOW() - INTERVAL '90 days';
```

#### Statistics Update
```sql
-- Update table statistics for query optimization
ANALYZE users;
ANALYZE accounts;
ANALYZE transactions;
ANALYZE active_sessions;
```

### Backup Procedures

#### Daily Backup Script
```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/postgresql"
DB_NAME="vubank_db"

# Create backup
pg_dump -h localhost -U vubank_user -d $DB_NAME \
    --no-password \
    --compress=9 \
    --file="$BACKUP_DIR/vubank_backup_$DATE.sql.gz"

# Clean up old backups (keep 30 days)
find $BACKUP_DIR -name "vubank_backup_*.sql.gz" -mtime +30 -delete
```

#### Point-in-Time Recovery Setup
```bash
# Enable WAL archiving in postgresql.conf
archive_mode = on
archive_command = 'cp %p /var/lib/postgresql/wal_archive/%f'
wal_level = replica
max_wal_senders = 3
```

## Security Considerations

### Data Protection
- **Password Hashing**: bcrypt with cost factor 12
- **JWT Token Hashing**: SHA-256 for session validation
- **IP Address Storage**: INET type for proper validation
- **Session Binding**: Sessions tied to originating IP

### Access Control
- **Role-Based Permissions**: Users assigned specific banking roles
- **Service Isolation**: Database access only through application services
- **Connection Security**: SSL required in production
- **Credential Management**: Environment variables for sensitive data

### Audit Trail
- **Complete Login Logging**: All authentication attempts recorded
- **Session Tracking**: Full session lifecycle audit
- **Transaction History**: Immutable transaction records
- **Request Correlation**: Unique IDs for request tracing

## Performance Optimization

### Query Performance
- **Strategic Indexing**: Indexes on frequently queried columns
- **Connection Pooling**: Reuse database connections
- **Query Analysis**: Regular EXPLAIN ANALYZE on critical queries
- **Statistics Maintenance**: Automatic statistics updates

### Monitoring Queries

#### Slow Query Identification
```sql
SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
FROM pg_stat_statements
ORDER BY mean_time DESC
LIMIT 10;
```

#### Index Usage Analysis
```sql
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;
```

#### Connection Monitoring
```sql
SELECT 
    state,
    COUNT(*) as connection_count
FROM pg_stat_activity
WHERE datname = 'vubank_db'
GROUP BY state;
```

## Development Environment

### Local Setup
```bash
# Start PostgreSQL container
docker run -d \
    --name vubank-postgres \
    -p 5432:5432 \
    -e POSTGRES_DB=vubank_db \
    -e POSTGRES_USER=vubank_user \
    -e POSTGRES_PASSWORD=vubank_pass \
    -v vubank_data:/var/lib/postgresql/data \
    postgres:15

# Initialize schema
psql -h localhost -U vubank_user -d vubank_db -f init.sql
```

### Test Data Generation
```sql
-- Generate additional test transactions
INSERT INTO transactions (account_id, transaction_type, amount, description, reference_number, balance_after)
SELECT 
    a.id,
    CASE WHEN random() > 0.5 THEN 'credit' ELSE 'debit' END,
    ROUND((random() * 2000 - 1000)::numeric, 2),
    'Generated test transaction #' || generate_series,
    'TEST' || LPAD(generate_series::text, 6, '0'),
    a.balance + ROUND((random() * 2000 - 1000)::numeric, 2)
FROM accounts a
CROSS JOIN generate_series(1, 10);
```

### Database Tools
- **pgAdmin**: Web-based database administration
- **psql**: Command-line PostgreSQL client
- **pg_dump/pg_restore**: Backup and restoration utilities
- **pgbench**: Database performance testing

## Troubleshooting

### Common Issues

#### Connection Issues
```sql
-- Check active connections
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query_start
FROM pg_stat_activity
WHERE datname = 'vubank_db';

-- Kill problematic connections
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'idle in transaction' 
    AND query_start < NOW() - INTERVAL '10 minutes';
```

#### Lock Monitoring
```sql
-- Check for blocking queries
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_statement,
    blocking_activity.query AS blocking_statement
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity 
    ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks 
    ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.DATABASE IS NOT DISTINCT FROM blocked_locks.DATABASE
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
JOIN pg_catalog.pg_stat_activity blocking_activity 
    ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

#### Storage Monitoring
```sql
-- Database size information
SELECT 
    pg_database.datname,
    pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database
ORDER BY pg_database_size(pg_database.datname) DESC;

-- Table size information
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```