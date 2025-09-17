-- Database initialization script for VuBank
-- Creates all necessary tables and initial data

-- Create roles table
CREATE TABLE IF NOT EXISTS roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create user_roles mapping table
CREATE TABLE IF NOT EXISTS user_roles (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    role_id INTEGER REFERENCES roles(id) ON DELETE CASCADE,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, role_id)
);

-- Create accounts table
CREATE TABLE IF NOT EXISTS accounts (
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

-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
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

-- Create login_requests table for audit
CREATE TABLE IF NOT EXISTS login_requests (
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

-- Create active_sessions table for session management
CREATE TABLE IF NOT EXISTS active_sessions (
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

-- Insert default roles
INSERT INTO roles (name, description) VALUES 
    ('retail', 'Retail banking customer'),
    ('corporate', 'Corporate banking customer'),
    ('admin', 'System administrator')
ON CONFLICT (name) DO NOTHING;

-- Insert test users with bcrypt hashed passwords
-- Password for all users is 'password123'
-- Hash generated with bcrypt: $2b$12$yhkx62UhXhfSst8XoYn6UOLtW7OfSgqoR6VyXpzH.npKs.pSK/tPa
INSERT INTO users (username, email, password_hash) VALUES 
    ('johndoe', 'john.doe@example.com', '$2b$12$yhkx62UhXhfSst8XoYn6UOLtW7OfSgqoR6VyXpzH.npKs.pSK/tPa'),
    ('janedoe', 'jane.doe@example.com', '$2b$12$yhkx62UhXhfSst8XoYn6UOLtW7OfSgqoR6VyXpzH.npKs.pSK/tPa'),
    ('corpuser', 'corporate@vubank.com', '$2b$12$yhkx62UhXhfSst8XoYn6UOLtW7OfSgqoR6VyXpzH.npKs.pSK/tPa')
ON CONFLICT (username) DO NOTHING;

-- Assign roles to users
INSERT INTO user_roles (user_id, role_id) VALUES 
    ((SELECT id FROM users WHERE username = 'johndoe'), (SELECT id FROM roles WHERE name = 'retail')),
    ((SELECT id FROM users WHERE username = 'janedoe'), (SELECT id FROM roles WHERE name = 'retail')),
    ((SELECT id FROM users WHERE username = 'corpuser'), (SELECT id FROM roles WHERE name = 'corporate'))
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Insert sample accounts
INSERT INTO accounts (user_id, account_number, account_name, account_type, balance, currency) VALUES 
    ((SELECT id FROM users WHERE username = 'johndoe'), '1001234567890', 'John Doe - Savings', 'savings', 25000.50, 'USD'),
    ((SELECT id FROM users WHERE username = 'johndoe'), '1001234567891', 'John Doe - Checking', 'checking', 5500.75, 'USD'),
    ((SELECT id FROM users WHERE username = 'janedoe'), '1001234567892', 'Jane Doe - Savings', 'savings', 32000.00, 'USD'),
    ((SELECT id FROM users WHERE username = 'corpuser'), '2001234567890', 'Corporate Account', 'business', 150000.00, 'USD')
ON CONFLICT (account_number) DO NOTHING;

-- Insert sample transactions
INSERT INTO transactions (account_id, transaction_type, amount, description, reference_number, balance_after) VALUES 
    ((SELECT id FROM accounts WHERE account_number = '1001234567890'), 'credit', 1000.00, 'Salary Deposit', 'SAL001', 25000.50),
    ((SELECT id FROM accounts WHERE account_number = '1001234567890'), 'debit', -200.00, 'ATM Withdrawal', 'ATM001', 24800.50),
    ((SELECT id FROM accounts WHERE account_number = '1001234567891'), 'credit', 500.00, 'Transfer In', 'TRF001', 5500.75),
    ((SELECT id FROM accounts WHERE account_number = '1001234567892'), 'credit', 2000.00, 'Direct Deposit', 'DD001', 32000.00),
    ((SELECT id FROM accounts WHERE account_number = '2001234567890'), 'credit', 50000.00, 'Business Payment', 'BP001', 150000.00);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON accounts(user_id);
CREATE INDEX IF NOT EXISTS idx_accounts_account_number ON accounts(account_number);
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_login_requests_user_id ON login_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_login_requests_attempted_at ON login_requests(attempted_at);
CREATE INDEX IF NOT EXISTS idx_active_sessions_user_id ON active_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_active_sessions_session_id ON active_sessions(session_id);
CREATE INDEX IF NOT EXISTS idx_active_sessions_expires_at ON active_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_active_sessions_is_active ON active_sessions(is_active);