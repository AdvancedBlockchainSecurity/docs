# Scanner Version Tracking

Database schema for tracking scanner versions, releases, and integration status.

## Quick Start

```bash
# Apply schema and load initial data
./apply_migration.sh

# View status
psql -d solidity_security -f query_helpers.sql

# Connect to database
psql -d solidity_security
```

## Files

- `schema.sql` - Database schema (tables, views, functions)
- `initial_data.sql` - Initial scanner data from ConfigMap
- `query_helpers.sql` - Common queries
- `apply_migration.sh` - Migration script
- `README.md` - This file

## Documentation

See `/Users/pwner/Git/ABS/database/SCANNER-VERSION-TRACKING.md` for complete documentation.

## Tables

- **scanner_versions** - Current scanner metadata and integration status
- **scanner_version_history** - Audit trail of version changes
- **scanner_release_tracking** - Upstream release monitoring

## Views

- **scanner_version_status** - Overview with calculated fields
- **outdated_scanners** - Scanners needing updates

## Quick Queries

```sql
-- All scanners
SELECT * FROM scanner_version_status;

-- Outdated
SELECT * FROM outdated_scanners;

-- Recent updates
SELECT * FROM scanner_version_history ORDER BY updated_at DESC LIMIT 5;

-- Record update
SELECT record_scanner_update('scanner_name', 'version', 'image_tag');
```
