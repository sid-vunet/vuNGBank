-- Database schema for CoreBanking Service
-- This script creates the necessary tables for the payment processing system

-- Create core_payments table for transaction records
CREATE TABLE IF NOT EXISTS core_payments (
    id SERIAL PRIMARY KEY,
    cbs_id UUID NOT NULL UNIQUE,
    txn_ref UUID NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL,
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

-- Create accounts table for account management and reporting
CREATE TABLE IF NOT EXISTS accounts (
    id SERIAL PRIMARY KEY,
    account_no VARCHAR(50) NOT NULL UNIQUE,
    account_type VARCHAR(20) NOT NULL,
    balance NUMERIC(15,2) NOT NULL DEFAULT 0.00,
    currency VARCHAR(3) NOT NULL DEFAULT 'INR',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for accounts
CREATE INDEX IF NOT EXISTS idx_accounts_account_no ON accounts(account_no);
CREATE INDEX IF NOT EXISTS idx_accounts_account_type ON accounts(account_type);

-- Insert sample account data for testing
INSERT INTO accounts (account_no, account_type, balance, currency) 
VALUES 
    ('1001234567', 'SAVINGS', 25000.00, 'INR'),
    ('1001234568', 'CURRENT', 50000.00, 'INR'),
    ('2001234567', 'SAVINGS', 15000.00, 'INR'),
    ('2001234568', 'CURRENT', 75000.00, 'INR')
ON CONFLICT (account_no) DO NOTHING;

-- Create a function to update account balance timestamp
CREATE OR REPLACE FUNCTION update_account_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically update timestamp
DROP TRIGGER IF EXISTS trigger_update_account_timestamp ON accounts;
CREATE TRIGGER trigger_update_account_timestamp
    BEFORE UPDATE ON accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_account_timestamp();

-- Add comments to tables and columns
COMMENT ON TABLE core_payments IS 'Core banking payments table storing all payment transactions';
COMMENT ON COLUMN core_payments.cbs_id IS 'Core Banking System generated unique identifier';
COMMENT ON COLUMN core_payments.txn_ref IS 'Transaction reference from payment processing service';
COMMENT ON COLUMN core_payments.status IS 'Payment status: PROCESSING, APPROVED, REJECTED';
COMMENT ON COLUMN core_payments.raw_json IS 'Original JSON payload for audit purposes';

COMMENT ON TABLE accounts IS 'Account master table for balance tracking and reporting';
COMMENT ON COLUMN accounts.account_no IS 'Unique account number';
COMMENT ON COLUMN accounts.balance IS 'Current account balance';
COMMENT ON COLUMN accounts.updated_at IS 'Last balance update timestamp';

-- Grant necessary permissions (adjust as needed for your environment)
-- GRANT SELECT, INSERT, UPDATE ON core_payments TO vubank_app_user;
-- GRANT SELECT, INSERT, UPDATE ON accounts TO vubank_app_user;
-- GRANT USAGE ON SEQUENCE core_payments_id_seq TO vubank_app_user;
-- GRANT USAGE ON SEQUENCE accounts_id_seq TO vubank_app_user;