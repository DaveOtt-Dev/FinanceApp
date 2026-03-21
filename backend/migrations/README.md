# Database Migration Guide

This document explains how to set up and run database migrations for the Finance App.

---

## Option 1: Raw SQL (Recommended for PostgreSQL-specific features)

### Setup

1. **Create a PostgreSQL database:**
   ```bash
   createdb finance_app
   ```

2. **Set environment variable:**
   ```bash
   export DATABASE_URL="postgresql://user:password@localhost:5432/finance_app"
   ```

3. **Run migrations:**
   ```bash
   psql $DATABASE_URL < backend/migrations/001_create_plaid_schema.sql
   ```

### Migration Files Structure

```
backend/
├── migrations/
│   ├── 001_create_plaid_schema.sql        ← Main schema (tables, indexes, functions)
│   ├── 002_add_webhook_support.sql        ← Future: Plaid webhooks
│   ├── 003_add_transactions_table.sql     ← Future: Transaction sync
│   └── README.md                          ← Migration documentation
```

### Running Migrations with a Migration Tool (SQLx, Flyway, etc.)

**Using SQLx (Rust):**
```bash
# Install SQLx CLI
cargo install sqlx-cli

# Prepare migrations
sqlx migrate run --database-url $DATABASE_URL
```

**Using Flyway (Java/Polyglot):**
```bash
# Install Flyway
# https://flywaydb.org/documentation/usage/commandline/

flyway -url=jdbc:postgresql://localhost:5432/finance_app \
       -user=postgres \
       -password=password \
       -locations=filesystem:backend/migrations \
       migrate
```

---

## Option 2: Prisma (Type-safe ORM with migrations)

Prisma is recommended if your backend is Node.js/TypeScript. It provides:
- Type-safe database queries
- Automatic migrations
- Prisma Studio for database exploration

### Setup

1. **Install Prisma:**
   ```bash
   npm install @prisma/client
   npm install -D prisma
   ```

2. **Initialize Prisma:**
   ```bash
   npx prisma init
   ```

3. **Set environment variable in `.env`:**
   ```
   DATABASE_URL="postgresql://user:password@localhost:5432/finance_app"
   ```

4. **Create initial migration:**
   ```bash
   npx prisma migrate dev --name init
   ```
   This will:
   - Create the migration file
   - Apply it to the database
   - Generate Prisma client

5. **Generate Prisma client:**
   ```bash
   npx prisma generate
   ```

### Using Prisma in Code

**Node.js/TypeScript:**
```typescript
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Get all accounts for a user with latest balances
async function getUserAccounts(userId: string) {
  const accounts = await prisma.plaidAccount.findMany({
    where: {
      userId,
      isActive: true,
    },
    include: {
      balances: {
        orderBy: { createdAt: 'desc' },
        take: 1, // Latest balance only
      },
    },
  });
  return accounts;
}

// Create a new sync log entry
async function logSync(
  entityType: 'item' | 'accounts' | 'balances',
  entityId: string,
  status: 'success' | 'failure' | 'partial',
  durationMs: number,
  recordsProcessed?: number,
  errorMessage?: string
) {
  return prisma.plaidSyncLog.create({
    data: {
      entityType,
      entityId,
      syncStatus: status,
      startedAt: new Date(),
      completedAt: new Date(),
      durationMs,
      recordsProcessed,
      errorMessage,
    },
  });
}

// Sync accounts from Plaid
async function syncAccountsFromPlaid(
  itemId: string,
  plaidItemId: string,
  plaidUserId: string,
  accountsFromPlaid: any[]
) {
  return prisma.$transaction(async (tx) => {
    // Upsert accounts
    for (const account of accountsFromPlaid) {
      await tx.plaidAccount.upsert({
        where: {
          plaidItemId_plaidAccountId: {
            plaidItemId,
            plaidAccountId: account.account_id,
          },
        },
        create: {
          plaidItemId,
          userId: plaidUserId,
          plaidAccountId: account.account_id,
          accountName: account.name,
          officialName: account.official_name,
          accountType: account.type,
          accountSubtype: account.subtype,
          accountMask: account.mask,
          currencyCode: account.balances.iso_currency_code || 'USD',
        },
        update: {
          accountName: account.name,
          officialName: account.official_name,
          accountSubtype: account.subtype,
        },
      });

      // Insert new balance snapshot
      const plaidAccount = await tx.plaidAccount.findUnique({
        where: { plaidAccountId: account.account_id },
      });

      await tx.plaidAccountBalance.create({
        data: {
          plaidAccountId: plaidAccount!.id,
          currentBalance: account.balances.current,
          availableBalance: account.balances.available,
          creditLimit: account.balances.limit,
          lastUpdatedFromPlaidAt: new Date(),
        },
      });
    }

    // Update item sync status
    await tx.plaidItem.update({
      where: { id: itemId },
      data: {
        lastSyncAt: new Date(),
        lastErrorMessage: null,
        lastErrorAt: null,
      },
    });
  });
}
```

### Prisma Migrations

**Create a new migration:**
```bash
npx prisma migrate dev --name add_transactions_table
```

**Reset database (development only):**
```bash
npx prisma migrate reset
```

**View migration status:**
```bash
npx prisma migrate status
```

**Explore data with Prisma Studio:**
```bash
npx prisma studio
```

---

## Option 3: Diesel (Rust ORM with migrations)

If your backend is Rust, Diesel provides type-safe queries and built-in migrations.

### Setup

1. **Install Diesel CLI:**
   ```bash
   cargo install diesel_cli --no-default-features --features postgres
   ```

2. **Setup Diesel:**
   ```bash
   diesel setup --database-url $DATABASE_URL
   ```

3. **Generate initial migration:**
   ```bash
   diesel migration generate create_plaid_schema
   ```

4. **Add migration content:**
   ```bash
   # Edit migrations/{timestamp}_create_plaid_schema/up.sql
   cat backend/migrations/001_create_plaid_schema.sql > migrations/{timestamp}_create_plaid_schema/up.sql

   # Create empty down.sql
   touch migrations/{timestamp}_create_plaid_schema/down.sql
   ```

5. **Run migrations:**
   ```bash
   diesel migration run --database-url $DATABASE_URL
   ```

---

## Backup Strategy

### Automated Backups

```bash
# Daily backup using pg_dump
0 2 * * * pg_dump $DATABASE_URL | gzip > /backups/finance_app_$(date +\%Y\%m\%d).sql.gz

# Keep 30 days of backups
find /backups -name "finance_app_*.sql.gz" -mtime +30 -delete
```

### Point-in-Time Recovery (PITR)

Enable WAL archiving in PostgreSQL:

```sql
-- In postgresql.conf
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /mnt/backup/%f && cp %p /mnt/backup/%f'
```

### Restore from Backup

```bash
# Restore full database
gunzip < /backups/finance_app_20260227.sql.gz | psql finance_app

# Restore to point-in-time (requires WAL archiving enabled)
pg_basebackup -D /var/lib/postgresql/restored -Fp -Pv
```

---

## Testing Migrations

### Local Testing

```bash
# Create test database
createdb finance_app_test

# Run migrations
psql finance_app_test < backend/migrations/001_create_plaid_schema.sql

# Verify schema
psql finance_app_test -c "\dt"  # List tables
```

### CI/CD Testing

```yaml
# GitHub Actions example
name: Test Database Migrations

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:14
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v2
      
      - name: Run migrations
        run: |
          export DATABASE_URL="postgresql://postgres:postgres@localhost/test_db"
          psql -U postgres -c "CREATE DATABASE test_db"
          psql -U postgres -d test_db < backend/migrations/001_create_plaid_schema.sql
      
      - name: Verify schema
        run: |
          psql -U postgres -d test_db -c "\dt"
```

---

## Production Deployment

### Pre-deployment Checklist

- [ ] Test migrations on staging database
- [ ] Backup production database
- [ ] Document rollback procedure
- [ ] Schedule downtime if needed (usually migrations can run online)
- [ ] Monitor database logs during migration
- [ ] Verify data integrity post-migration

### Rolling Out a Migration

1. **Test on staging:**
   ```bash
   psql staging_db < backend/migrations/002_new_migration.sql
   ```

2. **Backup production:**
   ```bash
   pg_dump production_db | gzip > production_backup.sql.gz
   ```

3. **Run on production:**
   ```bash
   psql production_db < backend/migrations/002_new_migration.sql
   ```

4. **Verify:**
   ```bash
   psql production_db -c "\dt"
   psql production_db -c "SELECT COUNT(*) FROM plaid_items;"
   ```

---

## Troubleshooting

### Migration Fails with "Column already exists"

**Problem:** Running the same migration twice
**Solution:** Check `schema_migrations` table (raw SQL) or Prisma's migration history
```bash
# Raw SQL
SELECT * FROM schema_migrations;

# Prisma
npx prisma migrate status
```

### "Too many connections" Error

**Problem:** Migration tool is creating too many database connections
**Solution:** Use connection pooling
```bash
# With PgBouncer
PgBouncer configuration: client_idle_timeout = 600
```

### Slow Migration on Large Tables

**Problem:** Migration time exceeds timeout
**Solution:** Add `CONCURRENTLY` option (available in PostgreSQL 11+)
```sql
CREATE INDEX CONCURRENTLY idx_new_index ON table_name(column);
```

### Rollback a Migration

**Raw SQL:**
```bash
# If migration is reversible, create down migration
vi backend/migrations/002_new_migration_down.sql
psql production_db < backend/migrations/002_new_migration_down.sql
```

**Prisma:**
```bash
npx prisma migrate resolve --rolled-back 002_migration_name
```

---

## Additional Resources

- **PostgreSQL Documentation:** https://www.postgresql.org/docs/
- **Prisma Migration Guide:** https://www.prisma.io/docs/concepts/components/prisma-migrate
- **Diesel Migration Guide:** https://diesel.rs/guides/getting-started/
- **SQLx Migration Guide:** https://github.com/launchbadge/sqlx/tree/main/sqlx-cli

