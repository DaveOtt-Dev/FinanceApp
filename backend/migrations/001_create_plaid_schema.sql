-- Finance App: PostgreSQL Schema for User Accounts and Plaid-Cached Financial Data
-- Migration: 001_create_plaid_schema.sql
-- Description: Creates the foundational tables for user management and Plaid data caching
-- Created: February 27, 2026

-- ========================================
-- USERS TABLE
-- ========================================
-- Stores application user accounts and authentication details
CREATE TABLE IF NOT EXISTS users (
    -- Primary identifier for the user
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- User authentication
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    
    -- User profile information
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    
    -- Account status
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_verified BOOLEAN NOT NULL DEFAULT false,
    email_verified_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Indexes for common queries
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_is_active ON users(is_active);
CREATE INDEX idx_users_created_at ON users(created_at);


-- ========================================
-- PLAID_ITEMS TABLE
-- ========================================
-- Stores Plaid Item data (represents a user's login to a financial institution)
-- Each Item can contain multiple Accounts from that institution
-- Reference: https://plaid.com/docs/api/items/
CREATE TABLE IF NOT EXISTS plaid_items (
    -- Primary identifier
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign key to users table
    user_id UUID NOT NULL,
    
    -- Plaid Item ID - uniquely identifies the login session with the institution
    plaid_item_id VARCHAR(255) NOT NULL UNIQUE,
    
    -- Encrypted access token - MUST be encrypted at rest using pgcrypto or KMS
    -- This token is used to call Plaid APIs to fetch account and transaction data
    -- CRITICAL: Never expose this to the iOS client
    access_token_encrypted BYTEA NOT NULL,
    
    -- Encryption key version (for key rotation support)
    encryption_key_version INTEGER DEFAULT 1,
    
    -- Institution metadata from Plaid
    institution_id VARCHAR(255),
    institution_name VARCHAR(255),
    
    -- Item status tracking
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_sync_at TIMESTAMP WITH TIME ZONE,
    
    -- Error tracking for failed syncs
    last_error_message TEXT,
    last_error_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_plaid_items_user_id 
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON DELETE CASCADE
);

-- Indexes for common queries
CREATE INDEX idx_plaid_items_user_id ON plaid_items(user_id);
CREATE INDEX idx_plaid_items_plaid_item_id ON plaid_items(plaid_item_id);
CREATE INDEX idx_plaid_items_is_active ON plaid_items(is_active);
CREATE INDEX idx_plaid_items_last_sync_at ON plaid_items(last_sync_at);


-- ========================================
-- PLAID_ACCOUNTS TABLE
-- ========================================
-- Stores account metadata returned from Plaid /accounts/get endpoint
-- Reference: https://plaid.com/docs/api/accounts/
CREATE TABLE IF NOT EXISTS plaid_accounts (
    -- Primary identifier
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign key to plaid_items table
    plaid_item_id UUID NOT NULL,
    
    -- Foreign key to users table (denormalized for query efficiency)
    user_id UUID NOT NULL,
    
    -- Plaid Account ID - uniquely identifies the account
    plaid_account_id VARCHAR(255) NOT NULL,
    
    -- Account metadata from Plaid API response
    account_name VARCHAR(255),                    -- User-provided account name
    official_name VARCHAR(255),                  -- Institution's official account name
    account_type VARCHAR(50) NOT NULL,           -- "depository", "credit", "loan", "investment", etc.
    account_subtype VARCHAR(50),                 -- "checking", "savings", "credit card", etc.
    
    -- Display information
    account_mask VARCHAR(4),                     -- Last 4 digits of account number
    currency_code CHAR(3) DEFAULT 'USD',         -- ISO 4217 currency code
    
    -- Account status
    is_active BOOLEAN NOT NULL DEFAULT true,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_plaid_accounts_plaid_item_id 
        FOREIGN KEY (plaid_item_id) 
        REFERENCES plaid_items(id) 
        ON DELETE CASCADE,
    CONSTRAINT fk_plaid_accounts_user_id 
        FOREIGN KEY (user_id) 
        REFERENCES users(id) 
        ON DELETE CASCADE,
    CONSTRAINT unique_account_per_item 
        UNIQUE (plaid_item_id, plaid_account_id)
);

-- Indexes for common queries
CREATE INDEX idx_plaid_accounts_user_id ON plaid_accounts(user_id);
CREATE INDEX idx_plaid_accounts_plaid_item_id ON plaid_accounts(plaid_item_id);
CREATE INDEX idx_plaid_accounts_plaid_account_id ON plaid_accounts(plaid_account_id);
CREATE INDEX idx_plaid_accounts_is_active ON plaid_accounts(is_active);


-- ========================================
-- PLAID_ACCOUNT_BALANCES TABLE
-- ========================================
-- Stores current and available balances for accounts
-- This table is updated on each sync to maintain balance history
-- Reference: https://plaid.com/docs/api/accounts/#accounts-get-response
CREATE TABLE IF NOT EXISTS plaid_account_balances (
    -- Primary identifier
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Foreign key to plaid_accounts table
    plaid_account_id UUID NOT NULL,
    
    -- Balance information from Plaid API
    -- current_balance: The total amount of funds in the account
    -- available_balance: The amount available to spend/withdraw
    -- Both values are in the account's currency_code
    current_balance NUMERIC(15, 2),
    available_balance NUMERIC(15, 2),
    
    -- Credit limit (for credit cards and lines of credit)
    credit_limit NUMERIC(15, 2),
    
    -- Last update from Plaid
    last_updated_from_plaid_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- When this record was created
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CONSTRAINT fk_plaid_account_balances_account_id 
        FOREIGN KEY (plaid_account_id) 
        REFERENCES plaid_accounts(id) 
        ON DELETE CASCADE
);

-- Indexes for common queries
CREATE INDEX idx_plaid_account_balances_plaid_account_id 
    ON plaid_account_balances(plaid_account_id);
CREATE INDEX idx_plaid_account_balances_created_at 
    ON plaid_account_balances(created_at);

-- Optional: Create a materialized view for latest balances per account
-- This helps avoid complex queries to find the most recent balance
CREATE INDEX idx_plaid_account_balances_latest 
    ON plaid_account_balances(plaid_account_id DESC, created_at DESC);


-- ========================================
-- PLAID_SYNC_LOG TABLE
-- ========================================
-- Tracks synchronization timestamps and status for Items and Accounts
-- Useful for monitoring sync health and implementing rate limiting
-- Optional but highly recommended for production systems
CREATE TABLE IF NOT EXISTS plaid_sync_log (
    -- Primary identifier
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- What entity was synced
    entity_type VARCHAR(50) NOT NULL,           -- "item", "accounts", "balances", "transactions"
    entity_id UUID NOT NULL,                    -- References plaid_items.id or plaid_accounts.id
    
    -- Sync status and timing
    sync_status VARCHAR(20) NOT NULL,           -- "success", "failure", "partial"
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    duration_ms INTEGER,                        -- Milliseconds taken to complete
    
    -- Result details
    records_processed INTEGER,                  -- Number of records synced
    error_message TEXT,                         -- Error details if sync_status = "failure"
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for common queries
CREATE INDEX idx_plaid_sync_log_entity_id ON plaid_sync_log(entity_id);
CREATE INDEX idx_plaid_sync_log_entity_type ON plaid_sync_log(entity_type);
CREATE INDEX idx_plaid_sync_log_created_at ON plaid_sync_log(created_at);
CREATE INDEX idx_plaid_sync_log_status ON plaid_sync_log(sync_status);


-- ========================================
-- EXTENSIONS & FUNCTIONS
-- ========================================

-- Enable pgcrypto extension for encryption
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Function to update the updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the trigger to all tables with updated_at
CREATE TRIGGER trigger_users_updated_at 
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_plaid_items_updated_at 
    BEFORE UPDATE ON plaid_items
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_plaid_accounts_updated_at 
    BEFORE UPDATE ON plaid_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();


-- ========================================
-- ENCRYPTION HELPER FUNCTION
-- ========================================
-- Helper function to encrypt sensitive data (access tokens)
-- This uses pgcrypto's pgp_sym_encrypt which provides strong encryption
-- Key management should be done via environment variables or KMS
-- 
-- Usage:
--   INSERT INTO plaid_items (user_id, plaid_item_id, access_token_encrypted)
--   VALUES (user_uuid, 'item_123', encrypt_token('actual_access_token', 'encryption_key'))
--
-- Note: In production, use AWS KMS or similar service instead of pgcrypto
CREATE OR REPLACE FUNCTION encrypt_token(token TEXT, encryption_key TEXT)
RETURNS BYTEA AS $$
BEGIN
    RETURN pgp_sym_encrypt(token, encryption_key, 'compress-algo=2, cipher-algo=aes256');
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Helper function to decrypt sensitive data
-- 
-- Usage:
--   SELECT decrypt_token(access_token_encrypted, 'encryption_key') 
--   FROM plaid_items 
--   WHERE id = item_uuid
--
CREATE OR REPLACE FUNCTION decrypt_token(encrypted_token BYTEA, encryption_key TEXT)
RETURNS TEXT AS $$
BEGIN
    RETURN pgp_sym_decrypt(encrypted_token, encryption_key);
END;
$$ LANGUAGE plpgsql IMMUTABLE;


-- ========================================
-- MATERIALIZED VIEW: USER_ACCOUNT_SUMMARY
-- ========================================
-- Provides a denormalized view for efficient querying of user account data
-- Useful for the iOS app to fetch all accounts and their latest balances in one query
CREATE MATERIALIZED VIEW IF NOT EXISTS user_account_summary AS
SELECT
    u.id AS user_id,
    u.email,
    pi.id AS plaid_item_id,
    pi.plaid_item_id,
    pi.institution_name,
    pa.id AS account_id,
    pa.plaid_account_id,
    pa.account_name,
    pa.official_name,
    pa.account_type,
    pa.account_subtype,
    pa.account_mask,
    pab.current_balance,
    pab.available_balance,
    pab.credit_limit,
    pab.last_updated_from_plaid_at,
    pa.is_active,
    ROW_NUMBER() OVER (
        PARTITION BY pa.id 
        ORDER BY pab.created_at DESC
    ) AS balance_rank
FROM users u
JOIN plaid_items pi ON u.id = pi.user_id
JOIN plaid_accounts pa ON pi.id = pa.plaid_item_id
LEFT JOIN plaid_account_balances pab ON pa.id = pab.plaid_account_id
WHERE u.is_active = true AND pi.is_active = true;

-- Index for efficient queries on the materialized view
CREATE UNIQUE INDEX idx_user_account_summary_latest 
    ON user_account_summary(user_id, account_id, balance_rank);
