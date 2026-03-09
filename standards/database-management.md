# Database Management and Recovery Standards

**Version:** 2.1.0
**Last Updated:** February 28, 2026
**Status:** Active

## Database Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| Database System | PostgreSQL 15.4 (pgvector) | |
| **Database Name** | `solidity_security` | NOT `blocksecops` - see note below |
| Default User | blocksecops | Via Vault/ExternalSecret |
| Schema | public | |
| **SSL** | **Enabled** | cert-manager local CA certs |
| SSL Mode | `hostssl` required for cluster connections | `hostnossl` rejected |
| TLS Certificates | `/etc/postgresql/certs-fixed/` | Copied from secret via initContainer |
| TLS Min Protocol | TLSv1.2 | |

> **Important:** The production database is named `solidity_security`, not `blocksecops`. This naming was established during initial platform development. All connection strings, scripts, and GCP migration plans should use this name.
>
> **Current Stats (January 18, 2026):** 15 scanners, 58 contracts, 115 scans, 6,317 vulnerabilities

### SSL/TLS Configuration (Updated February 2026)

PostgreSQL SSL is **enabled in all environments** including local development, using cert-manager generated certificates.

**Connection behavior:**
- Services using `asyncpg` connect with `ssl=prefer` by default, automatically upgrading to SSL when available
- `pg_hba.conf` enforces `hostssl` for all Kubernetes cluster connections (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- Non-SSL connections from the network are rejected (`hostnossl ... reject`)
- Local Unix socket connections use `trust` (no SSL needed for `kubectl exec` psql sessions)

**TLS certificate handling:**
- Certificates are issued by cert-manager local CA (`Certificate` resource `postgresql-certificate`)
- Kubernetes secret volumes mount files as 0640; PostgreSQL requires key files at 0600
- An `initContainer` (`fix-tls-permissions`) copies certs from the secret volume to an emptyDir with correct permissions before PostgreSQL starts

**Verify SSL status:**
```bash
# Check SSL is enabled
kubectl exec postgresql-0 -n postgresql-local -- psql -U blocksecops -c "SHOW ssl;"

# Check active SSL connections from services
kubectl exec postgresql-0 -n postgresql-local -- psql -U blocksecops -d solidity_security \
  -c "SELECT pid, usename, datname, ssl, client_addr FROM pg_stat_ssl JOIN pg_stat_activity USING (pid) WHERE datname IS NOT NULL;"
```

---

## Critical Database Safety Rules

**MANDATORY:** Never apply configuration changes to a running database without backups.

```
✅ CORRECT WORKFLOW:
1. Create database backup
2. Verify backup is valid
3. Apply configuration changes
4. Test database connectivity
5. Verify data integrity

❌ INCORRECT WORKFLOW:
1. Apply configuration changes to running database
2. Restart database to pick up changes
3. Discover authentication is broken
4. No backup available for recovery
```

**Why this matters:**
- **Data Loss Prevention:** Database corruption without backups means permanent data loss
- **Development Continuity:** Lost work impacts entire team
- **Configuration Safety:** Can safely test changes knowing recovery is possible
- **Debugging:** Can compare working vs broken state
- **Compliance:** Backup procedures required for production readiness

**Violations of this rule can result in unrecoverable data loss.**

## Rule 3: Automated Local Development Backups

**MANDATORY:** Create automated daily backups of local development databases.

### PostgreSQL Backup Script

Create `/Users/pwner/Git/ABS/scripts/backup-local-db.sh`:

```bash
#!/bin/bash
# Automated PostgreSQL backup for local development
# Run daily via cron: 0 2 * * * /Users/pwner/Git/ABS/scripts/backup-local-db.sh

set -euo pipefail

# Configuration
BACKUP_DIR="/Users/pwner/Git/ABS/backups/postgresql"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DB_NAME="solidity_security"

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Port forward PostgreSQL (if not already running)
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
PF_PID=$!
sleep 3

# Create backup
echo "Creating backup: ${DB_NAME}_${TIMESTAMP}.sql"
PGPASSWORD=postgres pg_dump \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d "$DB_NAME" \
  -F c \
  -f "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql"

# Compress backup
gzip "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql"

# Kill port forward
kill $PF_PID 2>/dev/null || true

# Verify backup
if [ -f "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz" ]; then
  SIZE=$(du -h "${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz" | cut -f1)
  echo "✅ Backup created successfully: ${SIZE}"
else
  echo "❌ Backup failed!"
  exit 1
fi

# Clean up old backups (keep last RETENTION_DAYS days)
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +$RETENTION_DAYS -delete
echo "✅ Cleaned up backups older than $RETENTION_DAYS days"

echo "Backup complete: ${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"
```

**Make script executable:**

```bash
chmod +x /Users/pwner/Git/ABS/scripts/backup-local-db.sh
```

**Set up automated backups (cron):**

```bash
# Open crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /Users/pwner/Git/ABS/scripts/backup-local-db.sh >> /Users/pwner/Git/ABS/logs/backup.log 2>&1
```

### Manual Backup Before Changes

**Before applying ANY database configuration changes:**

```bash
# 1. Create immediate backup
cd /Users/pwner/Git/ABS
./scripts/backup-local-db.sh

# 2. Verify backup exists
ls -lh backups/postgresql/

# 3. Test backup integrity
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 3
PGPASSWORD=postgres pg_restore --list \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  backups/postgresql/solidity_security_*.sql.gz | head -20

# 4. NOW proceed with changes
```

## Database Recovery Procedures

### Quick Recovery from Backup

If database becomes corrupted or inaccessible:

```bash
# 1. Find most recent backup
ls -lt /Users/pwner/Git/ABS/backups/postgresql/

# 2. Scale down PostgreSQL
kubectl scale deployment postgresql -n postgresql-local --replicas=0

# 3. Delete corrupted PVC
kubectl delete pvc postgresql-data -n postgresql-local

# 4. Scale up PostgreSQL (creates new PVC)
kubectl scale deployment postgresql -n postgresql-local --replicas=1
kubectl rollout status deployment postgresql -n postgresql-local

# 5. Wait for PostgreSQL to be ready
sleep 10

# 6. Port forward PostgreSQL
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 3

# 7. Create database
PGPASSWORD=postgres psql \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -c "CREATE DATABASE solidity_security;"

# 8. Restore from backup
BACKUP_FILE="/Users/pwner/Git/ABS/backups/postgresql/solidity_security_YYYYMMDD_HHMMSS.sql.gz"
gunzip -c "$BACKUP_FILE" | PGPASSWORD=postgres pg_restore \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d solidity_security \
  --no-owner \
  --no-acl \
  -v

# 9. Verify data restored
PGPASSWORD=postgres psql \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d solidity_security \
  -c "\dt" \
  -c "SELECT COUNT(*) FROM users;"

# 10. Restart API service to reconnect
kubectl rollout restart deployment api-service -n api-service-local
```

### Emergency Recovery Without Backup

**IF NO BACKUP EXISTS (data loss inevitable):**

```bash
# 1. Scale down PostgreSQL
kubectl scale deployment postgresql -n postgresql-local --replicas=0

# 2. Delete corrupted PVC
kubectl delete pvc postgresql-data -n postgresql-local
echo "⚠️  WARNING: All database data will be lost!"

# 3. Scale up PostgreSQL (fresh start)
kubectl scale deployment postgresql -n postgresql-local --replicas=1
kubectl rollout status deployment postgresql -n postgresql-local

# 4. Wait for PostgreSQL initialization
sleep 15

# 5. Port forward
kubectl port-forward -n postgresql-local svc/postgresql 5432:5432 &
sleep 3

# 6. Create database
PGPASSWORD=postgres psql \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -c "CREATE DATABASE solidity_security;"

# 7. Run Alembic migrations to recreate schema
cd /Users/pwner/Git/ABS/blocksecops-api-service
source .venv/bin/activate
export DATABASE_URL="postgresql+asyncpg://postgres:postgres@127.0.0.1:5432/solidity_security"
alembic upgrade head

# 8. Create test user
PGPASSWORD=postgres psql \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d solidity_security \
  -c "INSERT INTO users (id, email, password_hash, created_at) VALUES (
    '45b0f212-e9d5-4030-b489-4896ae1263cf',
    'test-rebrand@0xapogee.com',
    '\$2b\$12\$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LewY5TS0PgEqZQC6m',
    NOW()
  );"

# 9. Restart API service
kubectl rollout restart deployment api-service -n api-service-local

# 10. Test login
curl -X POST http://127.0.0.1:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test-rebrand@0xapogee.com","password":"TestPass123"}'
```

## Rule 4: Schema Documentation Must Stay Current

**MANDATORY:** Whenever database schema changes are made, `docs/database/SCHEMA.md` MUST be updated to reflect those changes before the work is considered complete.

**Applies to:**
- Alembic migrations that create or alter tables
- Manual SQL changes to the database
- Any ORM model changes that result in schema changes (new models, altered fields, new relationships)

**What must be updated in `docs/database/SCHEMA.md`:**
- **New tables** — Add full documentation including columns, types, constraints, indexes, and foreign keys
- **Altered columns** — Update column names, types, nullability, defaults, or constraints
- **Removed tables or columns** — Remove or mark as deprecated in the schema doc
- **New or dropped indexes** — Reflect index changes in the relevant table section
- **Table count** — Update the total table count in the document header or stats section
- **Verified date and stats** — Update the "Verified" date and any row-count or summary statistics

**Why this matters:**
- **Onboarding:** New developers rely on `SCHEMA.md` to understand the data model without inspecting the database directly
- **Debugging:** Accurate schema docs speed up incident response and root cause analysis
- **Audit trail:** Schema docs provide a human-readable record of the data model at any point in time
- **Migration safety:** Out-of-date docs cause confusion when reviewing or writing new migrations

```
✅ CORRECT WORKFLOW:
1. Write Alembic migration (or ORM model change)
2. Apply migration and verify it runs cleanly
3. Update docs/database/SCHEMA.md to match the new schema
4. Commit migration file and SCHEMA.md together in the same commit

❌ INCORRECT WORKFLOW:
1. Write and apply migration
2. Skip updating SCHEMA.md ("I'll do it later")
3. Schema doc drifts from reality
4. Future developers work from inaccurate documentation
```

**Violations of this rule leave the schema documentation in an inaccurate state and must be corrected immediately.**

## Pre-Change Checklist for Database Configuration

Before applying ANY changes to database configuration:

- [ ] **Backup created** - Run `./scripts/backup-local-db.sh`
- [ ] **Backup verified** - Confirm file exists and is valid
- [ ] **Changes documented** - Know exactly what will change
- [ ] **Rollback plan ready** - Know how to revert changes
- [ ] **Team notified** - If shared development environment
- [ ] **SCHEMA.md updated** - If the change affects the database schema, update `docs/database/SCHEMA.md`

**NEVER skip the backup step. Data loss is NOT acceptable.**

## Cautionary Example: Database Corruption Incident (October 16, 2025)

### What Happened

On October 16, 2025, a simple CORS configuration change resulted in complete loss of the local development database:

1. **Initial Change:** Updated CORS configuration in `configmap-patch.yaml` to prioritize `127.0.0.1`
2. **Applied Change:** Ran `kubectl apply -k k8s/overlays/local/api-service`
3. **Unintended Effect:** Kustomize also created/updated an ExternalSecret, changing database credentials
4. **First Problem:** API service couldn't authenticate to PostgreSQL (wrong password)
5. **Troubleshooting:** Multiple PostgreSQL restarts while attempting to fix authentication
6. **Second Problem:** Discovered PostgreSQL required SSL connections (from Sprint 14 Security Hardening)
7. **Attempted Fix:** Created local overlay to disable SSL for development
8. **Critical Failure:** PostgreSQL `pg_authid` file corrupted during multiple restarts
9. **Data Loss:** Database files intact but no users/roles exist - authentication system destroyed
10. **No Recovery:** No backups available - 10 days of development data lost permanently

### Root Causes

1. **No backups** - No automated or manual backups of local development database
2. **Dangerous changes** - Applied configuration changes to running database without safety net
3. **Incomplete understanding** - Didn't realize ExternalSecret would be created
4. **Multiple restarts** - Restarted PostgreSQL multiple times during troubleshooting
5. **No verification** - Didn't verify backup before making changes

### Lessons Learned

1. **ALWAYS create backups** before any database-related changes
2. **Test configuration changes** in isolation before applying to running systems
3. **Understand cascading effects** of Kustomize and other tools
4. **Minimize restarts** during troubleshooting - each restart increases corruption risk
5. **Verify assumptions** - Don't assume local environment is safe to break

### Prevention Measures

The following measures are now MANDATORY to prevent recurrence:

1. **Automated daily backups** of local development PostgreSQL database
2. **Pre-change backup requirement** - NO database config changes without backup
3. **Recovery procedure documentation** - Clear steps for database restoration
4. **Configuration testing** - Test Kustomize changes with `kubectl diff` first
5. **Change isolation** - Apply only the specific change needed, not entire overlays

**Remember this incident:** 10 days of development data lost permanently because backup was skipped before a "simple" CORS configuration change.

---

**See Also:**
- [Core Development Rules](./core-development-rules.md) - Critical development workflow rules
- [Secrets Management](./secrets-management.md) - Database credential management
- [Local Development Setup](../local-development/local-development-setup.md) - Local environment configuration
