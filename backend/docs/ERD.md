# Entity Relationship Diagram (ERD)

## Database Schema Overview

```
┌─────────────────────────────┐
│         USERS               │
├─────────────────────────────┤
│ PK  id (UUID)               │
│     email (UNIQUE)          │
│     password_hash           │
│     first_name              │
│     last_name               │
│     is_active               │
│     is_verified             │
│     email_verified_at       │
│     created_at              │
│     updated_at              │
│     deleted_at              │
└──────────┬──────────────────┘
           │ 1
           │
           │ n
           ├─────────────────────────────────────┐
           │                                     │
           │                    ┌────────────────────────────────────────┐
           │                    │    PLAID_ITEMS                         │
           │                    ├────────────────────────────────────────┤
           │                    │ PK  id (UUID)                          │
           │                    │ FK  user_id (UUID) ──────────┐         │
           │                    │     plaid_item_id (UNIQUE)   │         │
           │                    │     access_token_encrypted    │         │
           │                    │     encryption_key_version    │         │
           │                    │     institution_id            │         │
           │                    │     institution_name          │         │
           │                    │     is_active                 │         │
           │                    │     last_sync_at              │         │
           │                    │     last_error_message        │         │
           │                    │     created_at                │         │
           │                    │     updated_at                │         │
           │                    └──────┬───────────────────────┘         │
           │                           │ 1                               │
           │                           │                                │
           │                           │ n                              │
           │        ┌──────────────────┼──────────────────┐             │
           │        │                  │                  │             │
           │        │                  │                  │             │
           │   ┌────┴──────────────────┴────────────┐    │             │
           │   │    PLAID_ACCOUNTS                  │    │             │
           │   ├────────────────────────────────────┤    │             │
           │   │ PK  id (UUID)                      │    │             │
           │   │ FK  plaid_item_id (UUID) ──────────┼────┤             │
           │   │ FK  user_id (UUID) ────────────────┼────┼──(refer     │
           │   │     plaid_account_id (UNIQUE)      │    │   to users  │
           │   │     account_name                   │    │   for hist) │
           │   │     official_name                  │    │             │
           │   │     account_type                   │    │             │
           │   │     account_subtype                │    │             │
           │   │     account_mask                   │    │             │
           │   │     currency_code                  │    │             │
           │   │     is_active                      │    │             │
           │   │     created_at                     │    │             │
           │   │     updated_at                     │    │             │
           │   └────┬─────────────────────────────┬─┘    │             │
           │        │ 1                           │      │             │
           │        │                             │      │             │
           │        │ n                           │      │             │
           │        │                             │      │             │
           │        │                             │      │             │
           │   ┌────┴────────────────────────┐   │      │             │
           │   │ PLAID_ACCOUNT_BALANCES      │   │      │             │
           │   ├─────────────────────────────┤   │      │             │
           │   │ PK  id (UUID)               │   │      │             │
           │   │ FK  plaid_account_id ───────┼───┤      │             │
           │   │     current_balance         │   │      │             │
           │   │     available_balance       │   │      │             │
           │   │     credit_limit            │   │      │             │
           │   │ last_updated_from_plaid_at  │   │      │             │
           │   │     created_at              │   │      │             │
           │   └─────────────────────────────┘   │      │             │
           │                                     │      │             │
           │  ┌──────────────────────────────────┼──────┘             │
           │  │                                  │                    │
           │  │         ┌───────────────────────┘                    │
           │  │         │                                            │
           │  │    ┌────┴────────────────────────────────────────┐   │
           │  │    │     PLAID_SYNC_LOG                         │   │
           │  │    ├────────────────────────────────────────────┤   │
           │  │    │ PK  id (UUID)                              │   │
           │  │    │     entity_type (VARCHAR)                  │   │
           │  │    │     entity_id (UUID) ──────────────────────┼───┼──(plaid_items
           │  │    │     sync_status                            │   │   or accounts)
           │  │    │     started_at                             │   │
           │  │    │     completed_at                           │   │
           │  │    │     duration_ms                            │   │
           │  │    │     records_processed                      │   │
           │  │    │     error_message                          │   │
           │  │    │     created_at                             │   │
           │  │    └────────────────────────────────────────────┘   │
           │  │                                                     │
           └──┴─────────────────────────────────────────────────────┘
```

## Table Relationships

### 1. **USERS → PLAID_ITEMS** (One-to-Many)
   - A user can link to multiple financial institutions (multiple Plaid Items)
   - Each Plaid Item represents one login to a financial institution
   - ON DELETE CASCADE: Removing a user deletes all their linked items

### 2. **PLAID_ITEMS → PLAID_ACCOUNTS** (One-to-Many)
   - Each Plaid Item can have multiple accounts
   - For example: A user links their Bank of America account (1 Item) which has a Checking and Savings account (2 Accounts)
   - ON DELETE CASCADE: Removing an item deletes all its accounts

### 3. **PLAID_ACCOUNTS → PLAID_ACCOUNT_BALANCES** (One-to-Many)
   - Each account has a history of balance records
   - A new balance record is created on each sync
   - Allows tracking balance changes over time without losing historical data
   - ON DELETE CASCADE: Removing an account deletes its balance history

### 4. **PLAID_SYNC_LOG** (Tracking Table)
   - References either PLAID_ITEMS or PLAID_ACCOUNTS via entity_id
   - Helps track which syncs succeeded/failed and when
   - Useful for monitoring, alerting, and implementing sync rate limiting

### 5. **Denormalized User_ID in PLAID_ACCOUNTS**
   - While user_id can be derived via PLAID_ITEMS, it's denormalized here for query efficiency
   - Allows fast queries like "Get all accounts for user X" without joining through items
   - Maintains referential integrity with foreign key constraint

## Key Design Patterns

### Sensitive Data Encryption
- **access_token_encrypted** in PLAID_ITEMS is encrypted using pgcrypto
- The encryption key is managed outside the database (via environment variables or AWS KMS)
- Only the backend can decrypt these tokens; never exposed to iOS client

### Historical Data Retention
- PLAID_ACCOUNT_BALANCES stores every sync result, creating a balance history
- Enables features like "Balance trend" without additional API calls
- Soft delete via **deleted_at** (on users) allows data recovery

### Efficient Querying
- Indexes on frequently queried columns (user_id, is_active, created_at)
- Materialized view user_account_summary for efficient balance retrieval
- Consider PARTIAL indexes on is_active = true to further optimize

### Sync Tracking
- PLAID_SYNC_LOG enables monitoring of data freshness
- last_sync_at on PLAID_ITEMS tracks when items were last successfully synced
- error tracking helps with debugging and alerting

## Performance Considerations

### Indexes
```
users:
  - email (for login queries)
  - is_active (for filtering active users)
  - created_at (for timeline queries)

plaid_items:
  - user_id (for user lookups)
  - is_active (for active item filtering)
  - last_sync_at (for identifying stale data)

plaid_accounts:
  - user_id (for user balance dashboard)
  - plaid_item_id (for item details)
  - is_active (for filtering)

plaid_account_balances:
  - plaid_account_id + created_at DESC (for latest balance)
```

### Queries to Optimize For

1. **Get all accounts for a user with their latest balances**
   - Use the user_account_summary materialized view
   - Refreshed periodically (e.g., every hour)

2. **Get accounts that need syncing**
   - Query PLAID_ITEMS where last_sync_at < NOW() - interval '24 hours'

3. **Check sync health**
   - Query PLAID_SYNC_LOG for recent failures
   - Aggregate by entity_type and sync_status

## Future Extensions

These tables support future features:

- **Transactions**: Add plaid_transactions table referencing plaid_accounts
- **Liabilities**: Add plaid_liabilities table for loans and mortgages
- **Investments**: Add plaid_investments table for investment accounts
- **Webhooks**: Store Plaid webhook events for real-time sync triggers
- **Historical Snapshots**: Archive old balance records to separate table for archival

