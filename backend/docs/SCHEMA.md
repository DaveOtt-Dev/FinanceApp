# PostgreSQL Schema Documentation

## Overview

This document describes the Finance App's PostgreSQL database schema, which stores user accounts and Plaid-cached financial data. The schema follows Plaid's recommended Item → Account hierarchy and is designed for security, performance, and future scalability.

**Design Principles:**
- Security: Sensitive access tokens are encrypted and never exposed to the client
- Performance: Proper indexing and denormalization for common query patterns
- Auditability: All tables include timestamps and sync logs
- Extensibility: Supports future features like transactions, liabilities, and investments

---

## Table Specifications

### 1. USERS Table

**Purpose:** Stores application user accounts and authentication credentials.

**Schema:**
```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid()          -- Unique user identifier
email VARCHAR(255) NOT NULL UNIQUE                     -- Email (used for login)
password_hash VARCHAR(255) NOT NULL                    -- Bcrypt-hashed password
first_name VARCHAR(100)                                -- User's first name
last_name VARCHAR(100)                                 -- User's last name
is_active BOOLEAN NOT NULL DEFAULT true                -- Account active status
is_verified BOOLEAN NOT NULL DEFAULT false             -- Email verification status
email_verified_at TIMESTAMP WITH TIME ZONE             -- When email was verified
created_at TIMESTAMP WITH TIME ZONE NOT NULL           -- Account creation time
updated_at TIMESTAMP WITH TIME ZONE NOT NULL           -- Last modification time
deleted_at TIMESTAMP WITH TIME ZONE                    -- Soft delete timestamp (NULL = active)
```

**Key Features:**
- UUID primary key for distributed systems
- Soft delete via `deleted_at` for data recovery
- Email uniqueness enforced at database level
- Triggers maintain `updated_at` automatically

**Indexes:**
- `email` - For login queries
- `is_active` - For filtering active users
- `created_at` - For timeline analytics

---

### 2. PLAID_ITEMS Table

**Purpose:** Stores Plaid Item data. An Item represents a user's login to a financial institution.

**Key Concept:** Each user can link multiple institutions (e.g., Bank of America, Chase, Credit Union). Each link is a separate Item with its own access token and accounts.

**Schema:**
```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid()              -- Unique item identifier
user_id UUID NOT NULL                                      -- Reference to USERS table
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
plaid_item_id VARCHAR(255) NOT NULL UNIQUE                 -- Plaid's item identifier
access_token_encrypted BYTEA NOT NULL                      -- Encrypted access token (SENSITIVE)
encryption_key_version INTEGER DEFAULT 1                   -- For key rotation support
institution_id VARCHAR(255)                                -- Plaid institution ID (e.g., "ins_123")
institution_name VARCHAR(255)                              -- Human-readable institution name
is_active BOOLEAN NOT NULL DEFAULT true                    -- Whether this item is active
last_sync_at TIMESTAMP WITH TIME ZONE                      -- When accounts were last fetched
last_error_message TEXT                                    -- Error from last failed sync
last_error_at TIMESTAMP WITH TIME ZONE                     -- When the error occurred
created_at TIMESTAMP WITH TIME ZONE NOT NULL               -- Item linkage time
updated_at TIMESTAMP WITH TIME ZONE NOT NULL               -- Last update time
```

**Security:**
- `access_token_encrypted`: Encrypted using pgcrypto's `pgp_sym_encrypt()`
- Encryption key stored separately (environment variable or AWS KMS)
- Never exposed to iOS client - all account fetching done server-side
- `encryption_key_version` enables key rotation without breaking existing tokens

**Sync Tracking:**
- `last_sync_at`: Helps identify stale data needing refresh
- `last_error_message` & `last_error_at`: Debug failed syncs
- Use these to implement "retry failed syncs" endpoints

**Indexes:**
- `user_id` - Query items by user
- `plaid_item_id` - Direct item lookup
- `is_active` - Filter to active items only
- `last_sync_at` - Find items needing refresh

**Plaid API Mapping:**
| Column | Plaid Source |
|--------|--------------|
| `plaid_item_id` | Response from POST /link/token/create and token exchange |
| `institution_id` | institutions.institution_id from GET /institutions/:id |
| `institution_name` | institutions.name |

---

### 3. PLAID_ACCOUNTS Table

**Purpose:** Stores metadata for accounts within a Plaid Item.

**Key Concept:** A single Item can have multiple accounts. Example: BECU Item might have Checking, Savings, and Money Market accounts (3 PLAID_ACCOUNTS rows).

**Schema:**
```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid()                    -- Unique account identifier
plaid_item_id UUID NOT NULL                                      -- Reference to PLAID_ITEMS
  FOREIGN KEY (plaid_item_id) REFERENCES plaid_items(id) ON DELETE CASCADE
user_id UUID NOT NULL                                            -- Reference to USERS (denormalized)
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
plaid_account_id VARCHAR(255) NOT NULL                           -- Plaid account identifier
CONSTRAINT unique_account_per_item UNIQUE (plaid_item_id, plaid_account_id)
account_name VARCHAR(255)                                        -- Custom name (user-provided or Plaid)
official_name VARCHAR(255)                                       -- Institution's official name
account_type VARCHAR(50) NOT NULL                                -- Type classification
  -- Valid values: "depository", "credit", "loan", "investment", "mortgage"
account_subtype VARCHAR(50)                                      -- Subtype classification
  -- Valid depository: "checking", "savings", "money market", "prepaid"
  -- Valid credit: "credit card", "paypal", "line of credit"
  -- Valid loan: "auto", "mortgage", "student", "personal"
account_mask VARCHAR(4)                                          -- Last 4 digits (e.g., "4321")
currency_code CHAR(3) DEFAULT 'USD'                              -- ISO 4217 currency code
is_active BOOLEAN NOT NULL DEFAULT true                          -- Account is linked and syncing
created_at TIMESTAMP WITH TIME ZONE NOT NULL                     -- When account was discovered
updated_at TIMESTAMP WITH TIME ZONE NOT NULL                     -- Last metadata update
```

**Denormalization Note:**
- `user_id` is denormalized from `plaid_items` for query efficiency
- Eliminates need to join through PLAID_ITEMS to find user's accounts
- Foreign key maintains referential integrity

**Indexes:**
- `user_id` - Get all accounts for a user (balance dashboard)
- `plaid_item_id` - Get all accounts in an item
- `plaid_account_id` - Direct account lookup
- `is_active` - Filter active accounts

**Plaid API Mapping:**
| Column | Plaid Source |
|--------|--------------|
| `plaid_account_id` | accounts[].account_id from GET /accounts/get |
| `account_name` | accounts[].name |
| `official_name` | accounts[].official_name |
| `account_type` | accounts[].type |
| `account_subtype` | accounts[].subtype |
| `account_mask` | accounts[].mask |
| `currency_code` | accounts[].balances.iso_currency_code |

---

### 4. PLAID_ACCOUNT_BALANCES Table

**Purpose:** Stores historical balance snapshots for each account.

**Key Concept:** A new row is created on each sync. This maintains balance history without losing data, enabling features like "balance trend" visualization.

**Schema:**
```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid()                    -- Unique record identifier
plaid_account_id UUID NOT NULL                                   -- Reference to PLAID_ACCOUNTS
  FOREIGN KEY (plaid_account_id) REFERENCES plaid_accounts(id) ON DELETE CASCADE
current_balance NUMERIC(15, 2)                                   -- Total balance in account
available_balance NUMERIC(15, 2)                                 -- Available to spend/withdraw
credit_limit NUMERIC(15, 2)                                      -- Credit limit (cards/LOC only)
last_updated_from_plaid_at TIMESTAMP WITH TIME ZONE NOT NULL     -- When Plaid fetched this
created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()       -- When we stored this record
```

**Design Details:**
- `NUMERIC(15, 2)` accommodates up to $9,999,999,999.99 with cents precision
- NULL balances indicate account type doesn't have that metric (e.g., no credit_limit for checking)
- `last_updated_from_plaid_at` ≠ `created_at` because we might process a batch of syncs
- New record created on every sync - enables historical balance tracking

**Indexes:**
- `(plaid_account_id, created_at DESC)` - Get latest balance efficiently
- `created_at` - Query balances by date range (analytics)

**Latest Balance Query:**
```sql
SELECT * FROM plaid_account_balances
WHERE plaid_account_id = $1
ORDER BY created_at DESC
LIMIT 1;
```

**Plaid API Mapping:**
| Column | Plaid Source |
|--------|--------------|
| `current_balance` | accounts[].balances.current |
| `available_balance` | accounts[].balances.available |
| `credit_limit` | accounts[].balances.limit |

---

### 5. PLAID_SYNC_LOG Table

**Purpose:** Tracks synchronization jobs for monitoring, debugging, and audit trails.

**Schema:**
```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid()                   -- Record identifier
entity_type VARCHAR(50) NOT NULL                                -- What was synced
  -- Valid values: "item", "accounts", "balances", "transactions"
entity_id UUID NOT NULL                                         -- ID of plaid_items or plaid_accounts
sync_status VARCHAR(20) NOT NULL                                -- Result of sync
  -- Valid values: "success", "failure", "partial"
started_at TIMESTAMP WITH TIME ZONE NOT NULL                    -- When sync started
completed_at TIMESTAMP WITH TIME ZONE                           -- When sync ended
duration_ms INTEGER                                             -- Milliseconds to complete
records_processed INTEGER                                       -- How many records synced
error_message TEXT                                              -- Failure reason if status = "failure"
created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()      -- When we logged this
```

**Use Cases:**
1. **Monitoring:** Alert if sync fails repeatedly
2. **Rate Limiting:** Check how frequently we're syncing an item
3. **Debugging:** Find when/why a sync failed
4. **Analytics:** Track sync performance over time

**Indexes:**
- `entity_id` - Find all syncs for an item/account
- `entity_type` - Find all syncs of a particular type
- `sync_status` - Find all failures for debugging
- `created_at` - Query recent syncs

**Example Queries:**
```sql
-- Find items that haven't synced in 24+ hours
SELECT COUNT(*) FROM plaid_sync_log
WHERE entity_type = 'item' 
  AND sync_status = 'success'
  AND created_at < NOW() - INTERVAL '24 hours'
GROUP BY entity_id;

-- Check for recent failures
SELECT entity_id, error_message, completed_at
FROM plaid_sync_log
WHERE sync_status = 'failure'
  AND created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;
```

---

## Helper Functions

### `encrypt_token(token TEXT, encryption_key TEXT) → BYTEA`

Encrypts an access token using pgcrypto.

**Usage:**
```sql
INSERT INTO plaid_items (user_id, plaid_item_id, access_token_encrypted)
VALUES (
  '550e8400-e29b-41d4-a716-446655440000',
  'item_1234567890',
  encrypt_token('access-prod-abc123xyz', 'your-encryption-key')
);
```

**Note:** In production, use AWS KMS instead of pgcrypto for better key management.

---

### `decrypt_token(encrypted_token BYTEA, encryption_key TEXT) → TEXT`

Decrypts an access token using pgcrypto.

**Usage:**
```sql
SELECT decrypt_token(access_token_encrypted, 'your-encryption-key')
FROM plaid_items
WHERE id = '550e8400-e29b-41d4-a716-446655440000';
```

**Warning:** Only call this function server-side when you need to use the token with Plaid API. Never return the plain token to the client.

---

## Materialized Views

### `user_account_summary`

**Purpose:** Denormalized view for efficient iOS app queries.

**Query Result Columns:**
```
user_id, email, plaid_item_id, plaid_item_id, institution_name,
account_id, plaid_account_id, account_name, official_name, 
account_type, account_subtype, account_mask, current_balance, 
available_balance, credit_limit, last_updated_from_plaid_at, 
is_active, balance_rank
```

**Use Case:** Get all accounts for a user with their latest balances in a single query.

**Example Query:**
```sql
SELECT * FROM user_account_summary
WHERE user_id = $1 
  AND balance_rank = 1  -- Get only the latest balance per account
ORDER BY institution_name, account_name;
```

**Refresh Strategy:**
```sql
-- Refresh periodically (e.g., via cron job)
REFRESH MATERIALIZED VIEW CONCURRENTLY user_account_summary;
```

---

## Data Refresh Strategy

### Sync Flow

1. **User triggers account sync** (manual or scheduled)
2. **Backend fetches data from Plaid:**
   - Call `GET /accounts/get` using `access_token` from PLAID_ITEMS
3. **Update PLAID_ACCOUNTS** (metadata changes infrequently)
4. **Insert into PLAID_ACCOUNT_BALANCES** (new row each time)
5. **Log the sync** in PLAID_SYNC_LOG
6. **Update PLAID_ITEMS.last_sync_at**

### SQL Sync Example

```sql
BEGIN TRANSACTION;

-- Log the sync start
INSERT INTO plaid_sync_log (entity_type, entity_id, sync_status, started_at)
VALUES ('item', $item_id, 'success', NOW())
RETURNING id;

-- Assume Plaid returned accounts as JSON
-- Upsert accounts (update if exists, insert if new)
INSERT INTO plaid_accounts 
  (plaid_item_id, user_id, plaid_account_id, account_name, ...)
VALUES ($item_id, $user_id, $account_id, $account_name, ...)
ON CONFLICT (plaid_item_id, plaid_account_id) 
DO UPDATE SET account_name = $account_name, ...;

-- Insert new balance snapshot
INSERT INTO plaid_account_balances 
  (plaid_account_id, current_balance, available_balance, last_updated_from_plaid_at)
VALUES ($account_id, $current_balance, $available_balance, NOW());

-- Update item's last sync timestamp
UPDATE plaid_items 
SET last_sync_at = NOW(), last_error_message = NULL
WHERE id = $item_id;

-- Log the sync completion
UPDATE plaid_sync_log 
SET sync_status = 'success', completed_at = NOW(), duration_ms = ..., records_processed = ...
WHERE id = $sync_log_id;

COMMIT;
```

### Handling Sync Failures

```sql
BEGIN TRANSACTION;

UPDATE plaid_items
SET last_error_message = $error_message, last_error_at = NOW()
WHERE id = $item_id;

INSERT INTO plaid_sync_log 
  (entity_type, entity_id, sync_status, started_at, completed_at, error_message)
VALUES ('item', $item_id, 'failure', $started_at, NOW(), $error_message);

COMMIT;
```

---

## Cached Data vs. Live Data Strategy

### When to Use Cached Data
- **User opens the app** → Show cached balances immediately
- **Dashboard load** → Fetch from `user_account_summary` view (instant)
- **Offline support** → No network access, show cached data
- **Reduce Plaid API costs** → Cache hit = no API call

### When to Fetch Fresh Data
- **Pull-to-refresh** → User explicitly refreshes their accounts
- **Background sync** → Scheduled job (e.g., every 4 hours)
- **Critical operations** → Before displaying balances > $X for important decisions
- **Webhook notification** → Plaid sent a webhook, refresh immediately

### Recommended Sync Schedule
- **Initial link**: Sync immediately after account linking
- **Active users**: Sync every 4 hours
- **Inactive users**: Sync daily
- **Failed items**: Retry within 30 minutes, then back off exponentially

### API Response Strategy

**Get accounts for user (use cache):**
```json
GET /v1/user/accounts
Response: {
  "accounts": [
    {
      "account_id": "...",
      "account_name": "BECU Checking",
      "current_balance": 1200.50,
      "available_balance": 1200.50,
      "last_synced": "2026-02-27T14:30:00Z"
    }
  ]
}
```

**Refresh accounts endpoint (fetch fresh):**
```json
POST /v1/user/accounts/refresh
Response: {
  "status": "syncing",
  "estimated_completion": "2026-02-27T14:35:00Z"
}
```

---

## Encryption Strategy

### Current Implementation: pgcrypto
- Uses AES-256 symmetric encryption
- Encryption key stored in environment variable
- Suitable for development and small deployments

### Production Recommendation: AWS KMS
```python
# Pseudo-code for KMS-based encryption
import boto3
kms = boto3.client('kms')

# Encrypt
ciphertext = kms.encrypt(
    KeyId='arn:aws:kms:region:account:key/id',
    Plaintext=access_token
)['CiphertextBlob']

# Decrypt
plaintext = kms.decrypt(CiphertextBlob=ciphertext)['Plaintext']
```

### Key Rotation
1. Add `encryption_key_version` to PLAID_ITEMS
2. When rotating keys, decrypt with old key, encrypt with new key
3. Update `encryption_key_version`
4. Gradual migration prevents service interruption

---

## Production Checklist

- [ ] Enable SSL/TLS for database connections
- [ ] Set up automated backups (daily, with point-in-time recovery)
- [ ] Configure WAL archiving for disaster recovery
- [ ] Enable row-level security (RLS) if using Supabase/managed PostgreSQL
- [ ] Set up monitoring on slow queries (> 1s)
- [ ] Create indexes on all foreign keys
- [ ] Test the sync flow end-to-end
- [ ] Implement connection pooling (PgBouncer)
- [ ] Set up alerts for sync failures
- [ ] Document the backup and recovery procedure
- [ ] Test data encryption/decryption in production environment

---

## Troubleshooting

### Slow Account Queries
```sql
-- Check explain plan
EXPLAIN ANALYZE
SELECT * FROM plaid_accounts 
WHERE user_id = $1 AND is_active = true;

-- Consider partial index for common filters
CREATE INDEX idx_active_accounts ON plaid_accounts(user_id) 
WHERE is_active = true;
```

### High Disk Usage
```sql
-- Archive old balance records
DELETE FROM plaid_account_balances
WHERE created_at < NOW() - INTERVAL '1 year';

-- Or archive to separate table
INSERT INTO plaid_account_balances_archive 
SELECT * FROM plaid_account_balances 
WHERE created_at < NOW() - INTERVAL '1 year';
```

### Failed Syncs
```sql
-- Find failing items
SELECT pi.*, psl.error_message
FROM plaid_items pi
JOIN plaid_sync_log psl ON pi.id = psl.entity_id
WHERE psl.sync_status = 'failure'
  AND psl.created_at > NOW() - INTERVAL '1 hour'
ORDER BY psl.created_at DESC;
```

