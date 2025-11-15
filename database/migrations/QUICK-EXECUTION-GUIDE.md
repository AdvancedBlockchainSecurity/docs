# BVD Migration - Quick Execution Guide

**Status**: Ready for execution
**Time Required**: 15-30 minutes
**Risk Level**: Low (full backups + rollback available)

---

## 🚀 Quick Start (Automated)

### Option 1: Run Automated Script (Recommended)

```bash
# Navigate to migrations directory
cd /Users/pwner/Git/ABS/database/migrations

# Execute the migration script
./execute_bvd_migration.sh
```

**What it does**:
- ✅ Checks database connectivity
- ✅ Creates full database backup
- ✅ Creates table-specific backups
- ✅ Exports current data to CSV
- ✅ Executes migration SQL
- ✅ Verifies all changes
- ✅ Provides next steps

**Interactive prompts** allow you to review and confirm at each major step.

---

## 📋 Manual Execution (If Preferred)

### Step 1: Verify Database Access
```bash
psql -U blocksecops -d solidity_security -c "SELECT COUNT(*) FROM vulnerability_patterns;"
```

### Step 2: Create Backup
```bash
# Create backup directory
mkdir -p /Users/pwner/Git/ABS/database/backups/bvd-migration-$(date +%Y%m%d)

# Full backup
pg_dump -U blocksecops -d solidity_security -Fc \
  -f "/Users/pwner/Git/ABS/database/backups/bvd-migration-$(date +%Y%m%d)/full_backup_$(date +%Y%m%d_%H%M%S).dump"
```

### Step 3: Execute Migration
```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions

psql -U blocksecops -d solidity_security \
  -f 20251028_1230_add_bvd_prefix_to_pattern_codes.sql
```

### Step 4: Verify
```sql
psql -U blocksecops -d solidity_security <<EOF
-- All patterns should have BVD- prefix
SELECT COUNT(*) FROM vulnerability_patterns WHERE code LIKE 'BVD-%';
-- Should return: 60

-- No old format patterns
SELECT COUNT(*) FROM vulnerability_patterns WHERE code NOT LIKE 'BVD-%';
-- Should return: 0

-- Sample patterns
SELECT code, name FROM vulnerability_patterns ORDER BY code LIMIT 5;
EOF
```

### Step 5: Restart Services
```bash
# Choose based on your deployment:

# Docker Compose
docker-compose restart api-service

# Kubernetes
kubectl rollout restart deployment/blocksecops-api-service -n blocksecops

# Systemd
sudo systemctl restart blocksecops-api-service
```

---

## 🔧 Troubleshooting

### If psql command not found
```bash
# macOS
brew install postgresql@15

# Ubuntu/Debian
sudo apt-get install postgresql-client-15

# RHEL/CentOS
sudo yum install postgresql15
```

### If database connection fails
```bash
# Check PostgreSQL is running
ps aux | grep postgres

# Check connection settings
cat /Users/pwner/Git/ABS/blocksecops-api-service/.env | grep DATABASE

# Test connection
psql -U blocksecops -h localhost -d solidity_security
```

### If migration fails mid-execution
```bash
# Rollback using the generated script
cd /Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions

psql -U blocksecops -d solidity_security \
  -f 20251028_1230_rollback_bvd_prefix.sql
```

### If application won't start after migration
```bash
# Check if JSON file is updated
grep '"id": "BVD-' /Users/pwner/Git/ABS/blocksecops-api-service/seeds/vulnerability_patterns.json

# Should show all patterns with BVD- prefix
# If not, restore backup:
cp /Users/pwner/Git/ABS/blocksecops-api-service/seeds/vulnerability_patterns.json.backup-20251028_123000 \
   /Users/pwner/Git/ABS/blocksecops-api-service/seeds/vulnerability_patterns.json
```

---

## ✅ Verification Checklist

After migration, verify:

- [ ] Database backup created successfully
- [ ] All 60 patterns have BVD- prefix in database
- [ ] No old format patterns remain
- [ ] Vulnerability findings updated with BVD- codes
- [ ] Application starts without errors
- [ ] Can run a test scan
- [ ] New findings use BVD- pattern codes
- [ ] Historical findings remain accessible

---

## 🔄 Rollback Procedure

If you need to rollback:

```bash
# 1. Stop application
docker-compose stop api-service

# 2. Restore JSON backup
cd /Users/pwner/Git/ABS/blocksecops-api-service/seeds
cp vulnerability_patterns.json.backup-20251028_123000 vulnerability_patterns.json

# 3. Rollback database
cd /Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions
psql -U blocksecops -d solidity_security \
  -f 20251028_1230_rollback_bvd_prefix.sql

# 4. Restart application
docker-compose start api-service
```

---

## 📞 Support

### Issues During Migration
1. Check `/Users/pwner/Git/ABS/database/migrations/BVD-PREFIX-MIGRATION-PLAN.md` for detailed troubleshooting
2. Review PostgreSQL logs: `tail -f /var/log/postgresql/postgresql-15-main.log`
3. Check application logs: `docker-compose logs -f api-service`

### Files to Check
- Migration SQL: `/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20251028_1230_add_bvd_prefix_to_pattern_codes.sql`
- Rollback SQL: `/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/20251028_1230_rollback_bvd_prefix.sql`
- Pattern JSON: `/Users/pwner/Git/ABS/blocksecops-api-service/seeds/vulnerability_patterns.json`
- Schema docs: `/Users/pwner/Git/ABS/database/SCHEMA.md`

---

## 📊 Expected Results

### Before Migration
```sql
SELECT code FROM vulnerability_patterns LIMIT 3;
-- REE-001
-- REE-002
-- ACC-001
```

### After Migration
```sql
SELECT code FROM vulnerability_patterns LIMIT 3;
-- BVD-EVM-REE-001
-- BVD-EVM-REE-002
-- BVD-EVM-ACC-001
```

### Verification Query Results
```sql
-- Should return 60
SELECT COUNT(*) FROM vulnerability_patterns WHERE code LIKE 'BVD-%';

-- Should return 0
SELECT COUNT(*) FROM vulnerability_patterns WHERE code NOT LIKE 'BVD-%';
```

---

## 🎯 Success Criteria

Migration is successful when:
1. ✅ All 60 patterns have BVD- prefix in database
2. ✅ All vulnerability findings updated
3. ✅ No old format codes remain
4. ✅ Application starts successfully
5. ✅ Pattern matching works (run test scan)
6. ✅ No errors in application logs

---

## ⏱️ Timeline

| Step | Duration | Description |
|------|----------|-------------|
| Pre-checks | 2 min | Database connectivity, file checks |
| Backup | 5-10 min | Full + table backups |
| Migration | 2-5 min | SQL execution |
| Verification | 3-5 min | Verify results |
| Restart | 2-3 min | Application restart |
| **Total** | **15-30 min** | Depends on database size |

---

**Ready to execute?** Run:
```bash
cd /Users/pwner/Git/ABS/database/migrations
./execute_bvd_migration.sh
```
