# Finance App Backend - Database & API Documentation

## Overview

The Finance App backend handles user authentication, secure Plaid integration, and financial data caching. This document covers the database architecture and API design patterns.

---

## Architecture

```
iOS App (Finance)
    ↓
    ├─→ POST /v1/auth/register          → Create user
    ├─→ POST /v1/auth/login             → Authenticate user
    ├─→ POST /v1/item/link_token/create → Get link_token for Plaid Link
    ├─→ POST /v1/item/public_token/exchange → Exchange public_token
    ├─→ GET  /v1/accounts/get           → Get cached accounts (instant)
    └─→ POST /v1/accounts/refresh       → Trigger Plaid sync (background)

                    ↓
            PostgreSQL Database
            (Caches Plaid data securely)
            
                    ↓
            Plaid API (External)
            (Called only on refresh, not on app open)
```

### Key Design Decision: Cached vs. Live Data

**Problem:** Plaid API calls are rate-limited (~240/hour for some endpoints) and incur costs. Calling Plaid on every app open would be prohibitively expensive and slow.

**Solution:** Cache account data in PostgreSQL and refresh periodically.

```
User Opens App → Check Local Cache → Show Cached Balances (FAST)
                                                     ↓
User Pulls to Refresh → Call Plaid API → Update Cache → Show Fresh Data (SLOW)
```

---

## Database Schema

See [SCHEMA.md](SCHEMA.md) for complete documentation.

### Quick Summary

```
users
├── id (UUID)
├── email, password_hash
├── created_at, updated_at
└── Stores user accounts & authentication

plaid_items (represents a bank login)
├── id (UUID)
├── user_id (FK → users)
├── plaid_item_id (from Plaid)
├── access_token_encrypted (SENSITIVE - encrypted with pgcrypto/KMS)
├── institution_name
├── last_sync_at
└── Encrypted credentials for calling Plaid API

plaid_accounts (represents accounts within a bank)
├── id (UUID)
├── plaid_item_id (FK → plaid_items)
├── user_id (FK → users, denormalized)
├── plaid_account_id (from Plaid)
├── account_type, account_subtype
├── account_mask (last 4 digits)
└── Account metadata

plaid_account_balances (balance snapshots)
├── id (UUID)
├── plaid_account_id (FK → plaid_accounts)
├── current_balance, available_balance, credit_limit
├── last_updated_from_plaid_at
├── created_at
└── NEW ROW CREATED ON EACH SYNC (enables balance history)

plaid_sync_log (audit trail)
├── id (UUID)
├── entity_type ("item", "accounts", "balances")
├── entity_id (FK → plaid_items or plaid_accounts)
├── sync_status ("success", "failure", "partial")
├── started_at, completed_at, duration_ms
├── error_message (if failed)
└── Track every sync for monitoring/debugging
```

---

## API Endpoints

### Authentication

#### POST `/v1/auth/register`
Register a new user.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "secure_password",
  "first_name": "John",
  "last_name": "Doe"
}
```

**Response (201):**
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "auth_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

#### POST `/v1/auth/login`
Authenticate an existing user.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "secure_password"
}
```

**Response (200):**
```json
{
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "auth_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

---

### Plaid Integration

#### POST `/v1/item/link_token/create`
Get a `link_token` to present Plaid Link to the user.

**Purpose:** iOS app calls this to get the token needed to launch Plaid Link.

**Request:**
```json
{
  "client_user_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response (200):**
```json
{
  "link_token": "link-sandbox-abc123xyz",
  "expiration": "2026-02-27T14:35:00Z"
}
```

**Behind the Scenes:**
1. Backend receives request
2. Validates user is authenticated
3. Calls Plaid API: `POST https://sandbox.plaid.com/link/token/create` with backend's `client_id` and `secret`
4. Returns the `link_token` to iOS app
5. iOS app launches Plaid Link with this token
6. User authenticates with their bank

---

#### POST `/v1/item/public_token/exchange`
Exchange a `public_token` (from Plaid Link) for backend storage.

**Purpose:** After user authenticates in Plaid Link, iOS app sends the public_token. Backend exchanges it for an access_token and caches it.

**Request:**
```json
{
  "public_token": "public-sandbox-abc123xyz"
}
```

**Response (200):**
```json
{
  "item_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "success"
}
```

**Behind the Scenes:**
1. iOS app sends `public_token` to backend
2. Backend calls Plaid API: `POST https://sandbox.plaid.com/item/public_token/exchange` with `public_token`
3. Plaid returns `access_token` and `item_id`
4. Backend **encrypts** the `access_token` using pgcrypto/KMS
5. Backend stores encrypted token in `plaid_items.access_token_encrypted`
6. Returns to iOS app (public_token NEVER used by iOS again)
7. iOS app triggers `POST /accounts/refresh` in background

---

#### GET `/v1/accounts/get`
Get cached accounts for the authenticated user (from database, no Plaid call).

**Purpose:** iOS app calls this on app open to display accounts instantly.

**Request:**
```
GET /v1/accounts/get
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response (200):**
```json
{
  "accounts": [
    {
      "account_id": "550e8400-e29b-41d4-a716-446655440001",
      "item_id": "550e8400-e29b-41d4-a716-446655440000",
      "account_name": "BECU Checking",
      "official_name": "Business Checking Account",
      "account_type": "depository",
      "account_subtype": "checking",
      "account_mask": "1234",
      "current_balance": 1200.50,
      "available_balance": 1200.50,
      "credit_limit": null,
      "currency_code": "USD",
      "last_synced": "2026-02-27T14:30:00Z"
    },
    {
      "account_id": "550e8400-e29b-41d4-a716-446655440002",
      "item_id": "550e8400-e29b-41d4-a716-446655440000",
      "account_name": "BECU Savings",
      "official_name": "High Yield Savings",
      "account_type": "depository",
      "account_subtype": "savings",
      "account_mask": "5678",
      "current_balance": 5000.00,
      "available_balance": 5000.00,
      "credit_limit": null,
      "currency_code": "USD",
      "last_synced": "2026-02-27T14:30:00Z"
    }
  ],
  "last_synced": "2026-02-27T14:30:00Z"
}
```

**Implementation:**
```sql
SELECT 
  pa.id as account_id,
  pi.id as item_id,
  pa.account_name,
  pa.official_name,
  pa.account_type,
  pa.account_subtype,
  pa.account_mask,
  pab.current_balance,
  pab.available_balance,
  pab.credit_limit,
  pa.currency_code,
  pab.created_at as last_synced
FROM plaid_accounts pa
JOIN plaid_items pi ON pa.plaid_item_id = pi.id
LEFT JOIN LATERAL (
  SELECT * FROM plaid_account_balances
  WHERE plaid_account_id = pa.id
  ORDER BY created_at DESC
  LIMIT 1
) pab ON true
WHERE pa.user_id = $1 AND pa.is_active = true
ORDER BY pi.institution_name, pa.account_name;
```

---

#### POST `/v1/accounts/refresh`
Trigger a full sync of accounts from Plaid API.

**Purpose:** Called on pull-to-refresh, or scheduled via cron job.

**Request:**
```json
{
  "item_ids": ["550e8400-e29b-41d4-a716-446655440000"]
}
```

**Response (202 Accepted):**
```json
{
  "status": "syncing",
  "estimated_completion": "2026-02-27T14:35:00Z"
}
```

**Behind the Scenes (Async):**
1. Backend receives refresh request
2. Queues sync job for each item
3. **For each item:**
   - Decrypt `access_token` from database
   - Call Plaid API: `GET https://sandbox.plaid.com/accounts/get` with access_token
   - Upsert accounts into `plaid_accounts` table
   - Insert new row into `plaid_account_balances` for each account
   - Update `plaid_items.last_sync_at`
   - Log result in `plaid_sync_log`
4. **If sync fails:**
   - Update `plaid_items.last_error_message` and `last_error_at`
   - Log failure in `plaid_sync_log`
5. Return success to iOS app

**Sample Sync Job (Pseudocode):**
```python
async def sync_item(item_id: UUID, user_id: UUID):
    try:
        # Start sync log
        sync_log = SyncLog.create(
            entity_type='item',
            entity_id=item_id,
            sync_status='in_progress',
            started_at=now()
        )
        
        # Get encrypted token
        item = PlaidItem.get(item_id)
        access_token = decrypt(item.access_token_encrypted)
        
        # Call Plaid API
        accounts_response = plaid_client.accounts_get(
            access_token=access_token
        )
        
        # Update database
        for account in accounts_response.accounts:
            # Upsert account metadata
            plaid_account = PlaidAccount.upsert(
                plaid_item_id=item_id,
                plaid_account_id=account.account_id,
                account_name=account.name,
                official_name=account.official_name,
                account_type=account.type,
                account_subtype=account.subtype,
                account_mask=account.mask,
                currency_code=account.balances.iso_currency_code
            )
            
            # Insert new balance snapshot
            PlaidAccountBalance.create(
                plaid_account_id=plaid_account.id,
                current_balance=account.balances.current,
                available_balance=account.balances.available,
                credit_limit=account.balances.limit,
                last_updated_from_plaid_at=now()
            )
        
        # Update item sync status
        item.update(
            last_sync_at=now(),
            last_error_message=None,
            last_error_at=None
        )
        
        # Log success
        sync_log.update(
            sync_status='success',
            completed_at=now(),
            records_processed=len(accounts_response.accounts)
        )
        
    except PlaidError as e:
        # Log failure
        item.update(
            last_error_message=str(e),
            last_error_at=now()
        )
        
        sync_log.update(
            sync_status='failure',
            completed_at=now(),
            error_message=str(e)
        )
        
        raise
```

---

## Scheduled Sync Jobs

Implement these using your scheduler (APScheduler, Celery, Lambda, etc.):

### 1. Daily Full Sync
**Frequency:** Every 4 hours

```python
@scheduler.scheduled_job('interval', hours=4)
async def sync_all_items():
    """Sync all active items for all users"""
    items = PlaidItem.query.filter_by(is_active=True)
    for item in items:
        await sync_item(item.id, item.user_id)
```

### 2. Retry Failed Syncs
**Frequency:** Every 30 minutes

```python
@scheduler.scheduled_job('interval', minutes=30)
async def retry_failed_syncs():
    """Retry syncs that failed in the last hour"""
    failed = SyncLog.query.filter(
        SyncLog.sync_status == 'failure',
        SyncLog.created_at > now() - timedelta(hours=1)
    )
    for log in failed:
        await sync_item(log.entity_id, get_user_id(log.entity_id))
```

### 3. Cleanup Old Logs
**Frequency:** Daily

```python
@scheduler.scheduled_job('cron', hour=2, minute=0)
async def cleanup_old_logs():
    """Archive or delete sync logs older than 90 days"""
    old_logs = SyncLog.query.filter(
        SyncLog.created_at < now() - timedelta(days=90)
    )
    # Option 1: Delete
    old_logs.delete()
    
    # Option 2: Archive to separate table
    # INSERT INTO plaid_sync_log_archive SELECT * FROM plaid_sync_log WHERE ...
```

---

## Security Considerations

### 1. Access Token Encryption
- **Storage:** Encrypted in database using pgcrypto or AWS KMS
- **Never exposed:** Access token never returned to iOS client
- **Key management:** Keys stored in environment variables or KMS
- **Rotation:** Can rotate keys via `encryption_key_version` without losing data

### 2. Authentication & Authorization
- **iOS app:** Use JWT tokens issued on login
- **API endpoints:** Validate JWT on every request
- **Permissions:** Only allow users to access their own data

### 3. Rate Limiting
- **Plaid API:** Monitor usage to stay within rate limits
- **User endpoints:** Limit refresh requests to once per minute
- **Database:** Use connection pooling to prevent connection exhaustion

### 4. Data Validation
- **User input:** Validate and sanitize all inputs
- **Plaid responses:** Validate account data before storing
- **Error messages:** Don't expose internal details in error responses

---

## Monitoring & Alerting

### Key Metrics to Monitor

1. **Sync Success Rate**
   ```sql
   SELECT 
     COUNT(*) FILTER (WHERE sync_status = 'success') as successes,
     COUNT(*) FILTER (WHERE sync_status = 'failure') as failures,
     COUNT(*) * 100.0 / COUNT(*) FILTER (WHERE sync_status = 'success') as success_rate
   FROM plaid_sync_log
   WHERE created_at > NOW() - INTERVAL '24 hours';
   ```

2. **Stale Data**
   ```sql
   SELECT COUNT(*) as stale_items
   FROM plaid_items
   WHERE last_sync_at IS NULL 
      OR last_sync_at < NOW() - INTERVAL '24 hours';
   ```

3. **API Response Time**
   ```sql
   SELECT AVG(duration_ms) as avg_sync_time
   FROM plaid_sync_log
   WHERE created_at > NOW() - INTERVAL '1 hour'
     AND entity_type = 'item';
   ```

### Alert Conditions

- **Sync failure rate > 10%** in last hour → Page on-call engineer
- **Any items stale > 48 hours** → Investigate failed syncs
- **Average sync time > 30 seconds** → Optimize query or upgrade database

---

## Deployment Checklist

- [ ] Database migrations applied in production
- [ ] Encryption keys configured in environment
- [ ] SSL certificates valid for all connections
- [ ] Backups automated and tested (with point-in-time recovery)
- [ ] Monitoring and alerting configured
- [ ] Rate limiting implemented on all endpoints
- [ ] Logging and audit trails enabled
- [ ] Load testing completed (can handle peak traffic)
- [ ] Disaster recovery plan documented and tested
- [ ] Security audit completed (OWASP Top 10 review)

---

## Troubleshooting

### "Access Token Expired" Errors
Plaid access tokens don't expire, but Items can be revoked by users or the bank. Solution:
```sql
UPDATE plaid_items
SET is_active = false
WHERE id = $1;
```

### High Sync Failure Rate
1. Check `plaid_sync_log.error_message` for the actual error
2. Verify access tokens are still valid (user didn't revoke)
3. Check Plaid API status page for outages
4. Review database logs for connection/timeout issues

### Slow Account List Queries
```sql
-- Analyze query performance
EXPLAIN ANALYZE
SELECT * FROM user_account_summary
WHERE user_id = $1 AND balance_rank = 1;

-- Add partial indexes for common filters
CREATE INDEX idx_active_balances 
ON plaid_account_balances(plaid_account_id, created_at DESC)
WHERE ... some filter condition ...;
```

### High Database Disk Usage
Archive old balance records:
```sql
-- Move balances older than 1 year to archive table
INSERT INTO plaid_account_balances_archive
SELECT * FROM plaid_account_balances
WHERE created_at < NOW() - INTERVAL '1 year';

DELETE FROM plaid_account_balances
WHERE created_at < NOW() - INTERVAL '1 year';
```

---

## Next Steps

1. **Issue #3:** Implement backend REST API with authentication
2. **Issue #4:** Add transaction sync and caching
3. **Issue #5:** Implement Plaid webhooks for real-time updates

