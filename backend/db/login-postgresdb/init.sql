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
    currency VARCHAR(3) DEFAULT 'INR',
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
    ('corpuser', 'corporate@vubank.com', '$2b$12$yhkx62UhXhfSst8XoYn6UOLtW7OfSgqoR6VyXpzH.npKs.pSK/tPa'),
    ('sidharth', 'sidharth@vubank.com', '$2b$12$yhkx62UhXhfSst8XoYn6UOLtW7OfSgqoR6VyXpzH.npKs.pSK/tPa'),
    ('jithesh', 'jithesh@vubank.com', '$2b$12$yhkx62UhXhfSst8XoYn6UOLtW7OfSgqoR6VyXpzH.npKs.pSK/tPa'),
    ('bharath', 'bharath@vubank.com', '$2b$12$yhkx62UhXhfSst8XoYn6UOLtW7OfSgqoR6VyXpzH.npKs.pSK/tPa'),
    ('ashwin', 'ashwin@vubank.com', '$2b$12$yhkx62UhXhfSst8XoYn6UOLtW7OfSgqoR6VyXpzH.npKs.pSK/tPa'),
    ('rahjesh', 'rahjesh@vubank.com', '$2b$12$yhkx62UhXhfSst8XoYn6UOLtW7OfSgqoR6VyXpzH.npKs.pSK/tPa')
ON CONFLICT (username) DO NOTHING;

-- Assign roles to users
INSERT INTO user_roles (user_id, role_id) VALUES 
    ((SELECT id FROM users WHERE username = 'johndoe'), (SELECT id FROM roles WHERE name = 'retail')),
    ((SELECT id FROM users WHERE username = 'janedoe'), (SELECT id FROM roles WHERE name = 'retail')),
    ((SELECT id FROM users WHERE username = 'corpuser'), (SELECT id FROM roles WHERE name = 'corporate')),
    ((SELECT id FROM users WHERE username = 'sidharth'), (SELECT id FROM roles WHERE name = 'retail')),
    ((SELECT id FROM users WHERE username = 'jithesh'), (SELECT id FROM roles WHERE name = 'retail')),
    ((SELECT id FROM users WHERE username = 'bharath'), (SELECT id FROM roles WHERE name = 'retail')),
    ((SELECT id FROM users WHERE username = 'ashwin'), (SELECT id FROM roles WHERE name = 'retail')),
    ((SELECT id FROM users WHERE username = 'rahjesh'), (SELECT id FROM roles WHERE name = 'retail'))
ON CONFLICT (user_id, role_id) DO NOTHING;

-- Insert sample accounts with random balances
-- Savings: 50,000 to 2,50,000
-- Checking: 7,50,000 to 43,00,000
INSERT INTO accounts (user_id, account_number, account_name, account_type, balance, currency) VALUES 
    -- Original users
    ((SELECT id FROM users WHERE username = 'johndoe'), '1001234567890', 'John Doe - Savings', 'savings', 25000.50, 'INR'),
    ((SELECT id FROM users WHERE username = 'johndoe'), '1001234567891', 'John Doe - Checking', 'checking', 5500.75, 'INR'),
    ((SELECT id FROM users WHERE username = 'janedoe'), '1001234567892', 'Jane Doe - Savings', 'savings', 32000.00, 'INR'),
    ((SELECT id FROM users WHERE username = 'corpuser'), '2001234567890', 'Corporate Account', 'business', 150000.00, 'INR'),
    
    -- New users with random balances
    -- Sidharth accounts
    ((SELECT id FROM users WHERE username = 'sidharth'), '1001234567893', 'Sidharth - Savings', 'savings', 125750.00, 'INR'),
    ((SELECT id FROM users WHERE username = 'sidharth'), '1001234567894', 'Sidharth - Checking', 'checking', 1850000.00, 'INR'),
    
    -- Jithesh accounts
    ((SELECT id FROM users WHERE username = 'jithesh'), '1001234567895', 'Jithesh - Savings', 'savings', 87500.00, 'INR'),
    ((SELECT id FROM users WHERE username = 'jithesh'), '1001234567896', 'Jithesh - Checking', 'checking', 2125000.00, 'INR'),
    
    -- Bharath accounts
    ((SELECT id FROM users WHERE username = 'bharath'), '1001234567897', 'Bharath - Savings', 'savings', 198250.00, 'INR'),
    ((SELECT id FROM users WHERE username = 'bharath'), '1001234567898', 'Bharath - Checking', 'checking', 3675000.00, 'INR'),
    
    -- Ashwin accounts
    ((SELECT id FROM users WHERE username = 'ashwin'), '1001234567899', 'Ashwin - Savings', 'savings', 156000.00, 'INR'),
    ((SELECT id FROM users WHERE username = 'ashwin'), '1001234567810', 'Ashwin - Checking', 'checking', 2950000.00, 'INR'),
    
    -- Rahjesh accounts
    ((SELECT id FROM users WHERE username = 'rahjesh'), '1001234567811', 'Rahjesh - Savings', 'savings', 73200.00, 'INR'),
    ((SELECT id FROM users WHERE username = 'rahjesh'), '1001234567812', 'Rahjesh - Checking', 'checking', 4125000.00, 'INR')
ON CONFLICT (account_number) DO NOTHING;

-- Insert sample transactions for all accounts
INSERT INTO transactions (account_id, transaction_type, amount, description, reference_number, balance_after) VALUES 
    -- Original accounts
    ((SELECT id FROM accounts WHERE account_number = '1001234567890'), 'credit', 1000.00, 'Salary Deposit', 'SAL001', 25000.50),
    ((SELECT id FROM accounts WHERE account_number = '1001234567890'), 'debit', -200.00, 'ATM Withdrawal', 'ATM001', 24800.50),
    ((SELECT id FROM accounts WHERE account_number = '1001234567891'), 'credit', 500.00, 'Transfer In', 'TRF001', 5500.75),
    ((SELECT id FROM accounts WHERE account_number = '1001234567892'), 'credit', 2000.00, 'Direct Deposit', 'DD001', 32000.00),
    ((SELECT id FROM accounts WHERE account_number = '2001234567890'), 'credit', 50000.00, 'Business Payment', 'BP001', 150000.00),
    
    -- New user account transactions
    -- Sidharth
    ((SELECT id FROM accounts WHERE account_number = '1001234567893'), 'credit', 125000.00, 'Initial Deposit', 'INIT001', 125750.00),
    ((SELECT id FROM accounts WHERE account_number = '1001234567894'), 'credit', 1800000.00, 'Business Transfer', 'BT001', 1850000.00),
    
    -- Jithesh
    ((SELECT id FROM accounts WHERE account_number = '1001234567895'), 'credit', 85000.00, 'Salary Credit', 'SAL002', 87500.00),
    ((SELECT id FROM accounts WHERE account_number = '1001234567896'), 'credit', 2100000.00, 'Investment Deposit', 'INV001', 2125000.00),
    
    -- Bharath
    ((SELECT id FROM accounts WHERE account_number = '1001234567897'), 'credit', 195000.00, 'Bonus Payment', 'BON001', 198250.00),
    ((SELECT id FROM accounts WHERE account_number = '1001234567898'), 'credit', 3650000.00, 'Property Sale', 'PS001', 3675000.00),
    
    -- Ashwin
    ((SELECT id FROM accounts WHERE account_number = '1001234567899'), 'credit', 155000.00, 'Commission', 'COM001', 156000.00),
    ((SELECT id FROM accounts WHERE account_number = '1001234567810'), 'credit', 2900000.00, 'Contract Payment', 'CP001', 2950000.00),
    
    -- Rahjesh
    ((SELECT id FROM accounts WHERE account_number = '1001234567811'), 'credit', 70000.00, 'Freelance Payment', 'FP001', 73200.00),
    ((SELECT id FROM accounts WHERE account_number = '1001234567812'), 'credit', 4100000.00, 'Business Loan', 'BL001', 4125000.00);

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

-- ========================================
-- CoreBanking Service Tables
-- ========================================

-- Create core_payments table for transaction records
CREATE TABLE IF NOT EXISTS core_payments (
    id SERIAL PRIMARY KEY,
    cbs_id UUID NOT NULL UNIQUE,
    txn_ref UUID NOT NULL UNIQUE,
    status VARCHAR(50) NOT NULL,
    amount NUMERIC(15,2) NOT NULL,
    payer_account VARCHAR(50) NOT NULL,
    payee_account VARCHAR(50) NOT NULL,
    ifsc VARCHAR(11) NOT NULL,
    payment_type VARCHAR(10) NOT NULL,
    initiated_at TIMESTAMPTZ NOT NULL,
    approved_at TIMESTAMPTZ,
    comments VARCHAR(500),
    raw_json JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for core_payments
CREATE INDEX IF NOT EXISTS idx_core_payments_txn_ref ON core_payments(txn_ref);
CREATE INDEX IF NOT EXISTS idx_core_payments_cbs_id ON core_payments(cbs_id);
CREATE INDEX IF NOT EXISTS idx_core_payments_status ON core_payments(status);
CREATE INDEX IF NOT EXISTS idx_core_payments_payer_account ON core_payments(payer_account);
CREATE INDEX IF NOT EXISTS idx_core_payments_created_at ON core_payments(created_at);

-- Create core_accounts table for CoreBanking service (separate from login accounts)
CREATE TABLE IF NOT EXISTS core_accounts (
    id SERIAL PRIMARY KEY,
    account_no VARCHAR(50) NOT NULL UNIQUE,
    account_type VARCHAR(20) NOT NULL,
    balance NUMERIC(15,2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for core_accounts
CREATE INDEX IF NOT EXISTS idx_core_accounts_account_no ON core_accounts(account_no);
CREATE INDEX IF NOT EXISTS idx_core_accounts_account_type ON core_accounts(account_type);

-- Insert sample core account data for testing with matching balances
INSERT INTO core_accounts (account_no, account_type, balance, currency) 
VALUES 
    -- Original accounts
    ('1001234567890', 'SAVINGS', 25000.50, 'INR'),
    ('1001234567891', 'CURRENT', 5500.75, 'INR'),
    ('1001234567892', 'SAVINGS', 32000.00, 'INR'),
    ('2001234567890', 'CURRENT', 150000.00, 'INR'),
    
    -- New user accounts with matching balances (converted to INR equivalent)
    -- Sidharth accounts
    ('1001234567893', 'SAVINGS', 125750.00, 'INR'),
    ('1001234567894', 'CURRENT', 1850000.00, 'INR'),
    
    -- Jithesh accounts
    ('1001234567895', 'SAVINGS', 87500.00, 'INR'),
    ('1001234567896', 'CURRENT', 2125000.00, 'INR'),
    
    -- Bharath accounts
    ('1001234567897', 'SAVINGS', 198250.00, 'INR'),
    ('1001234567898', 'CURRENT', 3675000.00, 'INR'),
    
    -- Ashwin accounts
    ('1001234567899', 'SAVINGS', 156000.00, 'INR'),
    ('1001234567810', 'CURRENT', 2950000.00, 'INR'),
    
    -- Rahjesh accounts
    ('1001234567811', 'SAVINGS', 73200.00, 'INR'),
    ('1001234567812', 'CURRENT', 4125000.00, 'INR')
ON CONFLICT (account_no) DO NOTHING;

-- Create a function to update core account balance timestamp
CREATE OR REPLACE FUNCTION update_core_account_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update timestamp
DROP TRIGGER IF EXISTS trigger_update_core_account_timestamp ON core_accounts;
CREATE TRIGGER trigger_update_core_account_timestamp
    BEFORE UPDATE ON core_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_core_account_timestamp();

-- Add comments to new tables
COMMENT ON TABLE core_payments IS 'Core banking payments table storing all payment transactions';
COMMENT ON COLUMN core_payments.cbs_id IS 'Core Banking System generated unique identifier';
COMMENT ON COLUMN core_payments.txn_ref IS 'Transaction reference from payment processing service';
COMMENT ON COLUMN core_payments.status IS 'Payment status: PROCESSING, APPROVED, REJECTED';
COMMENT ON COLUMN core_payments.raw_json IS 'Original JSON payload for audit purposes';

COMMENT ON TABLE core_accounts IS 'Core account master table for balance tracking and reporting';
COMMENT ON COLUMN core_accounts.account_no IS 'Unique account number';
COMMENT ON COLUMN core_accounts.balance IS 'Current account balance';
COMMENT ON COLUMN core_accounts.updated_at IS 'Last balance update timestamp';

-- Create payees table for fund transfer recipients
CREATE TABLE IF NOT EXISTS payees (
    id SERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL,
    payee_name VARCHAR(100) NOT NULL,
    beneficiary_name VARCHAR(100) NOT NULL,
    account_number VARCHAR(20) NOT NULL,
    ifsc_code VARCHAR(11) NOT NULL,
    bank_name VARCHAR(100) NOT NULL,
    branch_name VARCHAR(100) NOT NULL,
    account_type VARCHAR(20) NOT NULL DEFAULT 'SAVINGS',
    mobile_number VARCHAR(15),
    email VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(50),
    branch_address TEXT,
    contact_number VARCHAR(20),
    micr_code VARCHAR(20),
    bank_code VARCHAR(10),
    rtgs_enabled BOOLEAN NOT NULL DEFAULT true,
    neft_enabled BOOLEAN NOT NULL DEFAULT true,
    imps_enabled BOOLEAN NOT NULL DEFAULT true,
    upi_enabled BOOLEAN NOT NULL DEFAULT true,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for payees
CREATE INDEX IF NOT EXISTS idx_payees_account_number ON payees(account_number);
CREATE INDEX IF NOT EXISTS idx_payees_ifsc_code ON payees(ifsc_code);
CREATE INDEX IF NOT EXISTS idx_payees_name ON payees(payee_name);
CREATE INDEX IF NOT EXISTS idx_payees_active ON payees(is_active);

-- Insert 10 random payees with actual IFSC codes and details
INSERT INTO payees (user_id, payee_name, beneficiary_name, account_number, ifsc_code, bank_name, branch_name, account_type, mobile_number, email, city, state, branch_address, contact_number, micr_code, bank_code) 
VALUES 
    ('4', 'Priya Sharma', 'Priya Sharma', '2234567890123456', 'SBIN0000123', 'State Bank of India', 'Connaught Place', 'SAVINGS', '+91-9876543210', 'priya.sharma@email.com', 'Mumbai', 'Maharashtra', 'Connaught Place Branch', '18001234567', 'SBIN001', 'SBIN'),
    ('4', 'Rahul Kumar', 'Rahul Kumar', '3345678901234567', 'HDFC0000456', 'HDFC Bank', 'Rajouri Garden', 'CURRENT', '+91-9876543211', 'rahul.kumar@email.com', 'Delhi', 'Delhi', 'Rajouri Garden Branch', '18001234568', 'HDFC002', 'HDFC'),
    ('4', 'Anita Verma', 'Anita Verma', '4456789012345678', 'ICIC0000789', 'ICICI Bank', 'Koramangala', 'SAVINGS', '+91-9876543212', 'anita.verma@email.com', 'Bangalore', 'Karnataka', 'Koramangala Branch', '18001234569', 'ICIC003', 'ICIC'),
    ('4', 'Vikram Singh', 'Vikram Singh', '5567890123456789', 'AXIS0000012', 'Axis Bank', 'Anna Nagar', 'CURRENT', '+91-9876543213', 'vikram.singh@email.com', 'Chennai', 'Tamil Nadu', 'Anna Nagar Branch', '18001234570', 'AXIS004', 'AXIS'),
    ('4', 'Meera Patel', 'Meera Patel', '6678901234567890', 'PUNB0000345', 'Punjab National Bank', 'Sector 17', 'SAVINGS', '+91-9876543214', 'meera.patel@email.com', 'Chandigarh', 'Punjab', 'Sector 17 Branch', '18001234571', 'PUNB005', 'PUNB'),
    ('4', 'Arjun Reddy', 'Arjun Reddy', '7789012345678901', 'CANR0000678', 'Canara Bank', 'Jayanagar', 'SAVINGS', '+91-9876543215', 'arjun.reddy@email.com', 'Mysore', 'Karnataka', 'Jayanagar Branch', '18001234572', 'CANR006', 'CANR'),
    ('4', 'Sushma Iyer', 'Sushma Iyer', '8890123456789012', 'BKID0000901', 'Bank of India', 'Shivaji Nagar', 'CURRENT', '+91-9876543216', 'sushma.iyer@email.com', 'Pune', 'Maharashtra', 'Shivaji Nagar Branch', '18001234573', 'BKID007', 'BKID'),
    ('4', 'Manoj Gupta', 'Manoj Gupta', '9901234567890123', 'UBIN0000234', 'Union Bank of India', 'Salt Lake', 'SAVINGS', '+91-9876543217', 'manoj.gupta@email.com', 'Kolkata', 'West Bengal', 'Salt Lake Branch', '18001234574', 'UBIN008', 'UBIN'),
    ('4', 'Deepika Nair', 'Deepika Nair', '1012345678901234', 'BARB0000567', 'Bank of Baroda', 'Alkapuri', 'CURRENT', '+91-9876543218', 'deepika.nair@email.com', 'Vadodara', 'Gujarat', 'Alkapuri Branch', '18001234575', 'BARB009', 'BARB'),
    ('4', 'Amit Joshi', 'Amit Joshi', '1123456789012345', 'IDIB0000890', 'Indian Bank', 'T. Nagar', 'SAVINGS', '+91-9876543219', 'amit.joshi@email.com', 'Chennai', 'Tamil Nadu', 'T. Nagar Branch', '18001234576', 'IDIB010', 'IDIB')
ON CONFLICT (id) DO NOTHING;

-- Add comments to payees table
COMMENT ON TABLE payees IS 'Payee master table for fund transfer recipients';
COMMENT ON COLUMN payees.ifsc_code IS 'Indian Financial System Code for bank branch identification';
COMMENT ON COLUMN payees.account_number IS 'Beneficiary account number';
COMMENT ON COLUMN payees.bank_name IS 'Name of the bank where account is held';
COMMENT ON COLUMN payees.branch_name IS 'Bank branch name';