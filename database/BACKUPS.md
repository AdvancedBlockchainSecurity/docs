# Database Backup Log

**Purpose:** Track all database backups created for the solidity_security database.

**Location:** All backups are stored in `/Users/pwner/Git/ABS/backups/`

**IMPORTANT:** Backups are created before any manual database modifications or major changes.

---

## Backup Policy

### When to Create Backups
1. Before any manual database fixes (UPDATE, DELETE, ALTER statements)
2. Before running new Alembic migrations
3. Before major version upgrades
4. Weekly scheduled backups (automated)
5. Before database schema changes
6. Before bulk data imports/exports

### Backup Retention
- **Development/Local:** Keep last 10 backups
- **Staging:** Keep last 30 backups
- **Production:** Keep daily backups for 30 days, weekly for 90 days

### Backup Verification
Each backup should be verified by:
1. Checking file size (should be > 0 bytes)
2. Verifying first 20 lines contain PostgreSQL dump headers
3. Testing restore to a temporary database (weekly)

---

## October 18, 2025 - Pre Scanner Comparison Fix

### Backup Details
**Filename:** `solidity_security_backup_20251018_114701.sql`
**Location:** `/Users/pwner/Git/ABS/backups/solidity_security_backup_20251018_114701.sql`
**Created:** October 18, 2025 11:47:01 MDT
**Size:** 135KB
**Database Version:** PostgreSQL 15.4

### Database State
**Tables:**
- `contracts`: 12 records
- `scans`: 31 records
- `vulnerabilities`: 43 records
- `users`: 5 records

**Schema Version:** Migration 004 (scanner tracking)

### Reason for Backup
Created before applying manual fix to populate `scanner_id` field for scanner comparison feature.

### Changes Applied After This Backup
```sql
UPDATE vulnerabilities SET scanner_id = 'slither' WHERE scanner_id IS NULL;
-- Updated 43 rows
```

### Restore Command
```bash
# Stop API service to prevent concurrent access
kubectl scale deployment/api-service -n api-service-local --replicas=0

# Restore database
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  < /Users/pwner/Git/ABS/backups/solidity_security_backup_20251018_114701.sql

# Restart API service
kubectl scale deployment/api-service -n api-service-local --replicas=1

# Verify data
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  -c "SELECT 'contracts' as table, COUNT(*) FROM contracts
      UNION ALL SELECT 'scans', COUNT(*) FROM scans
      UNION ALL SELECT 'vulnerabilities', COUNT(*) FROM vulnerabilities
      UNION ALL SELECT 'users', COUNT(*) FROM users;"
```

### Related Documentation
- [MANUAL-FIXES.md](/Users/pwner/Git/ABS/docs/database/MANUAL-FIXES.md) - October 18, 2025 entry
- [SCANNER-COMPARISON-FIX-2025-10-18.md](/Users/pwner/Git/ABS/docs/SCANNER-COMPARISON-FIX-2025-10-18.md)

---

## Backup Commands Reference

### Create Full Backup
```bash
# Basic backup
BACKUP_FILE="solidity_security_backup_$(date +%Y%m%d_%H%M%S).sql"
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U postgres -d solidity_security --clean --if-exists \
  > "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"

# Verify backup
ls -lh "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"
head -20 "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"
```

### Create Compressed Backup
```bash
BACKUP_FILE="solidity_security_backup_$(date +%Y%m%d_%H%M%S).sql.gz"
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U postgres -d solidity_security --clean --if-exists \
  | gzip > "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"
```

### Create Schema-Only Backup
```bash
BACKUP_FILE="solidity_security_schema_$(date +%Y%m%d_%H%M%S).sql"
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U postgres -d solidity_security --schema-only \
  > "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"
```

### Create Data-Only Backup
```bash
BACKUP_FILE="solidity_security_data_$(date +%Y%m%d_%H%M%S).sql"
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U postgres -d solidity_security --data-only \
  > "/Users/pwner/Git/ABS/backups/${BACKUP_FILE}"
```

### Create Table-Specific Backup
```bash
# Backup single table
kubectl exec -n postgresql-local postgresql-0 -- \
  pg_dump -U postgres -d solidity_security -t vulnerabilities \
  > "/Users/pwner/Git/ABS/backups/vulnerabilities_backup_$(date +%Y%m%d_%H%M%S).sql"
```

### Restore Database
```bash
# Full restore (WARNING: Drops existing data)
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security \
  < /Users/pwner/Git/ABS/backups/solidity_security_backup_YYYYMMDD_HHMMSS.sql

# Restore compressed backup
gunzip -c /Users/pwner/Git/ABS/backups/solidity_security_backup_YYYYMMDD_HHMMSS.sql.gz | \
  kubectl exec -i -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security
```

### List Backups
```bash
ls -lh /Users/pwner/Git/ABS/backups/ | grep solidity_security
```

### Verify Backup Integrity
```bash
# Check if backup is valid SQL
head -50 /Users/pwner/Git/ABS/backups/solidity_security_backup_YYYYMMDD_HHMMSS.sql

# Test restore to temporary database
kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -c "CREATE DATABASE solidity_security_test;"

kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -d solidity_security_test \
  < /Users/pwner/Git/ABS/backups/solidity_security_backup_YYYYMMDD_HHMMSS.sql

kubectl exec -n postgresql-local postgresql-0 -- \
  psql -U postgres -c "DROP DATABASE solidity_security_test;"
```

---

## Backup History Template

### [Date] - [Backup Name]

#### Backup Details
**Filename:** `filename.sql`
**Location:** `/Users/pwner/Git/ABS/backups/filename.sql`
**Created:** [Date and time]
**Size:** [File size]
**Database Version:** PostgreSQL X.Y

#### Database State
**Tables:**
- `table1`: X records
- `table2`: Y records

**Schema Version:** Migration XXX

#### Reason for Backup
[Why this backup was created]

#### Changes Applied After This Backup
```sql
-- SQL changes made after this backup
```

#### Restore Command
```bash
# Commands to restore this backup
```

#### Related Documentation
- [Link to related docs]

---

## Notes

- All backups include `--clean --if-exists` flags to drop existing objects before restore
- Backups are NOT automatically backed up to remote storage in local development
- Production backups should be stored in S3/GCS with encryption
- Test restore procedures monthly to ensure backup validity
- Document all manual database changes in MANUAL-FIXES.md
- Consider automating backups with a cron job or Kubernetes CronJob
