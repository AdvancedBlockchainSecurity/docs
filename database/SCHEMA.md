# BlockSecOps Database Schema

**Version:** 1.1.1
**Database:** PostgreSQL 15.4
**Last Updated:** October 20, 2025
**Migration Version:** 004 (08bf8921767b) + Manual Fix (is_project column)

## Table of Contents

1. [Overview](#overview)
2. [Entity Relationship Diagram](#entity-relationship-diagram)
3. [Tables](#tables)
4. [ENUM Types](#enum-types)
5. [Indexes](#indexes)
6. [Relationships](#relationships)
7. [Migration History](#migration-history)

---

## Overview

The BlockSecOps database supports a comprehensive smart contract security scanning platform with:

- **Multi-language support:** 21+ blockchain languages including Solidity, Vyper, Rust, Move, Cairo, and more
- **Multi-file contracts:** Support for complex projects with multiple source files
- **Project organization:** Group related contracts into projects
- **User authentication:** Session-based authentication with JWT tokens
- **Security scanning:** Vulnerability detection with severity classification and multi-scanner support
- **Scanner tracking:** Attribution and categorization of vulnerabilities by detection tool (Migration 004)
- **Saved searches:** User-saved search queries with JSONB parameters (Migration 004)
- **User preferences:** Customizable notification settings and UI preferences (Migration 004)
- **Performance optimization:** 13+ specialized indexes including GIN, composite, and partial indexes (Migration 004)
- **Audit tracking:** Full timestamps and status tracking

**Database Name:** `solidity_security`
**Schema:** `public` (default)
**Timezone:** UTC (all timestamps use `timestamp with time zone`)

---

## Entity Relationship Diagram

```
┌─────────────────┐
│     users       │
└────────┬────────┘
         │
         │ 1:N
         ├──────────────────────────────────────────────────────┬─────────────────┬──────────────────┐
         │                                                      │                 │                  │
         │                                                      │                 │                  │
┌────────▼─────────┐                                  ┌─────────▼──────┐  ┌───────▼────────┐  ┌────▼──────────────┐
│    sessions      │                                  │   projects     │  │saved_searches  │  │user_preferences   │
└──────────────────┘                                  └────────┬───────┘  └────────────────┘  └───────────────────┘
                                                               │                                   (1:1 with users)
                                                               │ M:N
         ┌─────────────────────────────────────────────────────┤
         │                                                     │
         │ 1:N                                        ┌────────▼──────────────┐
┌────────▼─────────┐                                  │ project_contracts     │
│    contracts     │◄─────────────────────────────────┤                       │
└────────┬─────────┘                                  └───────────────────────┘
         │
         │ 1:N
         ├─────────────────┬──────────────────┐
         │                 │                  │
┌────────▼──────────┐ ┌────▼──────┐  ┌───────▼──────────────┐
│ contract_files    │ │   scans   │  │  vulnerabilities     │
└───────────────────┘ └─────┬─────┘  └──────────────────────┘
                            │
                            │ 1:N
                            │
                      ┌─────▼──────────────┐
                      │  vulnerabilities   │
                      └────────────────────┘
```

---

## Tables

### `users`

User accounts with authentication credentials.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique user identifier |
| `email` | VARCHAR(255) | NOT NULL, UNIQUE | User email address |
| `hashed_password` | VARCHAR(255) | NOT NULL | Bcrypt hashed password |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true | Account active status |
| `is_superuser` | BOOLEAN | NOT NULL, DEFAULT false | Admin privileges flag |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Account creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_users_email` (UNIQUE) on `email`

**Relationships:**
- One-to-many with `sessions`
- One-to-many with `contracts`
- One-to-many with `scans`
- One-to-many with `projects`

---

### `sessions`

Active user authentication sessions with JWT tokens.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique session identifier |
| `user_id` | UUID | NOT NULL, FK → users.id | Associated user |
| `token` | VARCHAR(500) | NOT NULL, UNIQUE | JWT access token |
| `refresh_token` | VARCHAR(500) | UNIQUE, NULLABLE | JWT refresh token |
| `expires_at` | TIMESTAMPTZ | NOT NULL | Token expiration time |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Session creation time |
| `is_revoked` | BOOLEAN | NOT NULL, DEFAULT false | Session revocation status |

**Indexes:**
- `ix_sessions_user_id` on `user_id`
- `ix_sessions_token` (UNIQUE) on `token`
- `ix_sessions_refresh_token` (UNIQUE) on `refresh_token`

**Relationships:**
- Many-to-one with `users` (user_id)

---

### `projects`

Project containers for organizing related contracts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique project identifier |
| `name` | VARCHAR(255) | NOT NULL | Project name |
| `description` | TEXT | NULLABLE | Project description |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | Project owner |
| `settings` | JSONB | NOT NULL, DEFAULT '{}'::jsonb | Project-specific settings |
| `default_scan_profile` | VARCHAR(50) | NOT NULL, DEFAULT 'standard' | Default scan configuration |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Project creation time |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), ON UPDATE now() | Last update time |

**Indexes:**
- `ix_projects_user_id` on `user_id`
- `ix_projects_name` on `name`
- `ix_projects_created_at` on `created_at`

**Relationships:**
- Many-to-one with `users` (user_id)
- Many-to-many with `contracts` through `project_contracts`

---

### `project_contracts`

Junction table linking projects to contracts (many-to-many).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `project_id` | UUID | PRIMARY KEY, FK → projects.id ON DELETE CASCADE | Associated project |
| `contract_id` | UUID | PRIMARY KEY, FK → contracts.id ON DELETE CASCADE | Associated contract |
| `added_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | When contract was added to project |

**Indexes:**
- `ix_project_contracts_project_id` on `project_id`
- `ix_project_contracts_contract_id` on `contract_id`

**Composite Primary Key:** (`project_id`, `contract_id`)

**Relationships:**
- Many-to-one with `projects` (project_id)
- Many-to-one with `contracts` (contract_id)

---

### `contracts`

Smart contract source code and metadata.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique contract identifier |
| `user_id` | UUID | NOT NULL, FK → users.id | Contract owner |
| `name` | VARCHAR(255) | NOT NULL | Contract name |
| `address` | VARCHAR(42) | NULLABLE | Deployed contract address (if applicable) |
| `network` | VARCHAR(50) | NOT NULL | Blockchain network (e.g., "ethereum", "polygon") |
| `source_code` | TEXT | NULLABLE | Full source code (single file) |
| `bytecode` | TEXT | NULLABLE | Compiled bytecode |
| `lines_of_code` | INTEGER | NOT NULL | LOC for main file |
| `is_multi_file` | BOOLEAN | NOT NULL, DEFAULT false | Multi-file project flag |
| `is_project` | BOOLEAN | NOT NULL, DEFAULT false | Full project structure flag (for scanner compatibility) |
| `main_file_path` | VARCHAR(500) | NULLABLE | Path to main contract file |
| `file_count` | INTEGER | NOT NULL, DEFAULT 1 | Number of source files |
| `total_lines_of_code` | INTEGER | NOT NULL, DEFAULT 0 | Total LOC across all files |
| `language` | contract_language | NOT NULL | Programming language |
| `compiler_version` | VARCHAR(50) | NULLABLE | Compiler version used |
| `language_metadata` | JSONB | NULLABLE | Language-specific metadata |
| `status` | contract_status | NOT NULL | Current processing status |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Upload timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_contracts_user_id` on `user_id`
- `ix_contracts_address` on `address`
- `ix_contracts_language` on `language`

**Relationships:**
- Many-to-one with `users` (user_id)
- One-to-many with `contract_files`
- One-to-many with `scans`
- One-to-many with `vulnerabilities`
- Many-to-many with `projects` through `project_contracts`

---

### `contract_files`

Individual source files for multi-file contracts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique file identifier |
| `contract_id` | UUID | NOT NULL, FK → contracts.id ON DELETE CASCADE | Parent contract |
| `file_path` | VARCHAR(500) | NOT NULL | Relative file path |
| `file_content` | TEXT | NOT NULL | File source code |
| `is_main_file` | BOOLEAN | NOT NULL, DEFAULT false | Main entry point flag |
| `file_size` | INTEGER | NOT NULL | File size in bytes |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Upload timestamp |

**Indexes:**
- `ix_contract_files_contract_id` on `contract_id`

**Relationships:**
- Many-to-one with `contracts` (contract_id, CASCADE DELETE)

---

### `scans`

Security scan execution records.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique scan identifier |
| `contract_id` | UUID | NOT NULL, FK → contracts.id | Scanned contract |
| `user_id` | UUID | NOT NULL, FK → users.id | User who initiated scan |
| `scan_type` | VARCHAR(50) | NOT NULL | Scan type (e.g., "full", "quick", "custom") |
| `status` | scan_status | NOT NULL | Current scan status |
| `started_at` | TIMESTAMPTZ | NULLABLE | Scan start time |
| `completed_at` | TIMESTAMPTZ | NULLABLE | Scan completion time |
| `error_message` | TEXT | NULLABLE | Error details if scan failed |
| `critical_count` | INTEGER | NOT NULL | Count of critical vulnerabilities |
| `high_count` | INTEGER | NOT NULL | Count of high severity issues |
| `medium_count` | INTEGER | NOT NULL | Count of medium severity issues |
| `low_count` | INTEGER | NOT NULL | Count of low severity issues |
| `scanners_used` | ARRAY(VARCHAR(50)) | NULLABLE | Array of scanner IDs used in this scan |
| `scan_config` | JSONB | NULLABLE, DEFAULT '{}' | Scanner configuration parameters |
| `duration_seconds` | INTEGER | NULLABLE | Scan duration in seconds |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Scan queue time |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last status update |

**Indexes:**
- `ix_scans_contract_id` on `contract_id`
- `ix_scans_user_id` on `user_id`

**Relationships:**
- Many-to-one with `contracts` (contract_id)
- Many-to-one with `users` (user_id)
- One-to-many with `vulnerabilities`

---

### `vulnerabilities`

Detected security vulnerabilities and code issues.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique vulnerability identifier |
| `scan_id` | UUID | NOT NULL, FK → scans.id | Associated scan |
| `contract_id` | UUID | NOT NULL, FK → contracts.id | Affected contract |
| `title` | VARCHAR(255) | NOT NULL | Vulnerability title/name |
| `description` | TEXT | NOT NULL | Detailed description |
| `severity` | vulnerability_severity | NOT NULL | Severity level |
| `status` | vulnerability_status | NOT NULL | Current status |
| `swc_id` | VARCHAR(100) | NULLABLE | Smart Contract Weakness ID |
| `line_number` | INTEGER | NULLABLE | Line number in source |
| `code_snippet` | TEXT | NULLABLE | Relevant code excerpt |
| `recommendation` | TEXT | NULLABLE | Remediation guidance |
| `scanner_id` | VARCHAR(50) | NULLABLE | Scanner tool that detected this (e.g., slither, mythril, aderyn) |
| `category` | VARCHAR(100) | NULLABLE | Vulnerability type category (e.g., reentrancy, access_control) |
| `confidence` | NUMERIC(3,2) | NULLABLE | Scanner confidence score (0.0 to 1.0) |
| `detected_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Detection timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last status update |

**Indexes:**
- `ix_vulnerabilities_scan_id` on `scan_id`
- `ix_vulnerabilities_contract_id` on `contract_id`
- `ix_vulnerabilities_severity` on `severity`

**Relationships:**
- Many-to-one with `scans` (scan_id)
- Many-to-one with `contracts` (contract_id)

---

### `saved_searches`

User-saved search queries for quick re-execution.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique search identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | Search owner |
| `name` | VARCHAR(255) | NOT NULL | Search name |
| `description` | TEXT | NULLABLE | Search description |
| `search_params` | JSONB | NOT NULL | JSON object containing SearchRequest parameters |
| `last_executed_at` | TIMESTAMPTZ | NULLABLE | Last execution timestamp |
| `execution_count` | INTEGER | NOT NULL, DEFAULT 0 | Number of times executed |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_saved_searches_user_id` on `user_id`
- `ix_saved_searches_created_at` on `created_at DESC`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)

---

### `user_preferences`

User-specific settings and preferences.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `user_id` | UUID | PRIMARY KEY, FK → users.id ON DELETE CASCADE | User identifier (1:1 relationship) |
| `email_notifications` | BOOLEAN | NOT NULL, DEFAULT true | Enable email notifications |
| `scan_completion_notifications` | BOOLEAN | NOT NULL, DEFAULT true | Notify on scan completion |
| `critical_vulnerability_alerts` | BOOLEAN | NOT NULL, DEFAULT true | Alert on critical vulnerabilities |
| `weekly_digest` | BOOLEAN | NOT NULL, DEFAULT false | Send weekly summary email |
| `theme` | VARCHAR(20) | NOT NULL, DEFAULT 'light' | UI theme (light/dark) |
| `timezone` | VARCHAR(50) | NOT NULL, DEFAULT 'UTC' | User timezone |
| `language` | VARCHAR(10) | NOT NULL, DEFAULT 'en' | UI language code |
| `preferences` | JSONB | NULLABLE, DEFAULT '{}' | Additional preferences as JSON |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Relationships:**
- One-to-one with `users` (user_id, CASCADE DELETE)

---

## ENUM Types

### `contract_language`

Supported blockchain programming languages.

**Values:**
- `solidity` - Ethereum/EVM smart contracts
- `vyper` - Ethereum/EVM (Python-like)
- `rust` - Solana programs
- `move` - Aptos/Sui smart contracts
- `cairo` - StarkNet contracts
- `tact` - TON blockchain
- `clarity` - Stacks blockchain
- `yul` - EVM intermediate language
- `huff` - Low-level EVM
- `fe` - Python-inspired EVM language
- `simplicity` - Bitcoin-based language
- `michelson` - Tezos smart contracts
- `plutus` - Cardano smart contracts
- `sway` - Fuel Network
- `cadence` - Flow blockchain
- `motoko` - Internet Computer
- `ink` - Polkadot smart contracts
- `zinc` - zkSync contracts
- `leo` - Aleo programs
- `near` - NEAR Protocol
- `cosmos` - Cosmos SDK

**Usage:** `contracts.language`

---

### `contract_status`

Contract processing lifecycle status.

**Values:**
1. `uploaded` - Initial state after upload
2. `pending` - Awaiting scan initiation
3. `scanning` - Scan in progress
4. `scanned` - Scan completed successfully
5. `failed` - Scan/processing failed

**Usage:** `contracts.status`

**Status Flow:**
```
uploaded → pending → scanning → scanned
                            ↓
                         failed
```

---

### `scan_status`

Scan execution status.

**Values:**
- `queued` - Waiting for worker
- `running` - Scan in progress
- `completed` - Successfully finished
- `failed` - Scan failed with error

**Usage:** `scans.status`

**Status Flow:**
```
queued → running → completed
                ↓
             failed
```

---

### `vulnerability_severity`

Vulnerability severity classification (CVSS-inspired).

**Values (ordered):**
1. `critical` - Immediate action required
2. `high` - Significant security risk
3. `medium` - Moderate security concern
4. `low` - Minor issue or best practice

**Usage:** `vulnerabilities.severity`

---

### `vulnerability_status`

Vulnerability lifecycle tracking.

**Values:**
- `open` - Newly detected, unaddressed
- `acknowledged` - Reviewed but not yet fixed
- `fixed` - Remediated
- `false_positive` - Not a real vulnerability

**Usage:** `vulnerabilities.status`

---

## Indexes

### Performance Indexes

All indexes are created for query optimization based on common access patterns:

**Users:**
- `ix_users_email` - Login queries (UNIQUE)

**Sessions:**
- `ix_sessions_user_id` - User session lookup
- `ix_sessions_token` - Token validation (UNIQUE)
- `ix_sessions_refresh_token` - Token refresh (UNIQUE)

**Projects:**
- `ix_projects_user_id` - User's projects list
- `ix_projects_name` - Project name search
- `ix_projects_created_at` - Recent projects sorting

**Project Contracts:**
- `ix_project_contracts_project_id` - Contracts in project
- `ix_project_contracts_contract_id` - Project membership

**Contracts:**
- `ix_contracts_user_id` - User's contracts list
- `ix_contracts_address` - Contract lookup by address
- `ix_contracts_language` - Filter by language

**Contract Files:**
- `ix_contract_files_contract_id` - Files for contract

**Scans:**
- `ix_scans_contract_id` - Contract scan history
- `ix_scans_user_id` - User's scan activity
- `ix_scans_scanners_used` (GIN) - Scanner filtering on array

**Vulnerabilities:**
- `ix_vulnerabilities_scan_id` - Vulnerabilities in scan
- `ix_vulnerabilities_contract_id` - Contract vulnerability history
- `ix_vulnerabilities_severity` - Filter/sort by severity
- `ix_vulnerabilities_scanner_id` - Filter by scanner
- `ix_vulnerabilities_category` - Filter by category

**Saved Searches:**
- `ix_saved_searches_user_id` - User's saved searches
- `ix_saved_searches_created_at` - Recent searches sorting

**Composite Indexes:**
- `ix_vulns_contract_severity_status` on `vulnerabilities(contract_id, severity, status)`
- `ix_scans_user_status_created` on `scans(user_id, status, created_at DESC)`
- `ix_contracts_user_language_created` on `contracts(user_id, language, created_at DESC)`
- `ix_vulnerabilities_scan_severity` on `vulnerabilities(scan_id, severity)`
- `ix_project_contracts_added` on `project_contracts(project_id, added_at DESC)`

**Partial Indexes:**
- `ix_scans_user_completed` on `scans(user_id, completed_at DESC) WHERE status = 'completed'`
- `ix_vulnerabilities_open` on `vulnerabilities(contract_id, severity) WHERE status = 'open'`
- `ix_scans_failed` on `scans(user_id, created_at DESC) WHERE status = 'failed'`

---

## Relationships

### Foreign Key Constraints

**CASCADE DELETE:**
- `contract_files.contract_id` → `contracts.id` (DELETE CASCADE)
- `project_contracts.project_id` → `projects.id` (DELETE CASCADE)
- `project_contracts.contract_id` → `contracts.id` (DELETE CASCADE)
- `projects.user_id` → `users.id` (DELETE CASCADE)

**RESTRICT DELETE (default):**
- `sessions.user_id` → `users.id`
- `contracts.user_id` → `users.id`
- `scans.contract_id` → `contracts.id`
- `scans.user_id` → `users.id`
- `vulnerabilities.scan_id` → `scans.id`
- `vulnerabilities.contract_id` → `contracts.id`

---

## Migration History

| Version | Date | Description | File |
|---------|------|-------------|------|
| **001** | 2025-10-12 | Initial database schema with users, contracts, scans, vulnerabilities, multi-language and multi-file support | `20251012_1500-001_initial_schema.py` |
| **002** | 2025-10-14 | Add 'uploaded' status to contract_status enum | `20251014_1400-002_add_uploaded_status.py` |
| **003** | 2025-10-15 | Add projects table and project_contracts junction table for project organization | `20251015_1000-003_add_projects_table.py` |
| **004** | 2025-10-18 | Comprehensive production enhancements: scanner tracking, vulnerability categorization, saved searches, user preferences, and 13 performance indexes | `20251017_2112-08bf8921767b_comprehensive_production_enhancements_.py` |

**Note:** After October 16, 2025 database recovery, migration 002 required manual application. See [MANUAL-FIXES.md](./MANUAL-FIXES.md) for details on any required manual fixes when recreating the database.

### Running Migrations

**Apply all migrations:**
```bash
cd /Users/pwner/Git/ABS/blocksecops-api-service
source .venv/bin/activate
export DATABASE_URL="postgresql+asyncpg://postgres:postgres@127.0.0.1:5432/solidity_security"
alembic upgrade head
```

**Check current version:**
```bash
alembic current
```

**Generate new migration:**
```bash
alembic revision -m "description"
```

**Rollback last migration:**
```bash
alembic downgrade -1
```

---

## Database Configuration

### Connection Settings

**Local Development:**
```
Host: 127.0.0.1
Port: 5432
Database: solidity_security
User: postgres
Password: postgres
```

**Connection String:**
```
postgresql+asyncpg://postgres:postgres@127.0.0.1:5432/solidity_security
```

### PostgreSQL Configuration

**Version:** PostgreSQL 15.4-alpine
**SSL:** Disabled for local development
**Authentication:** scram-sha-256
**Timezone:** UTC

---

## Backup and Recovery

**Backup Script:** `/Users/pwner/Git/ABS/scripts/backup-local-db.sh`

**Manual Backup:**
```bash
PGPASSWORD=postgres pg_dump \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d solidity_security \
  -F c \
  -f backup.sql
```

**Restore from Backup:**
```bash
PGPASSWORD=postgres pg_restore \
  -h 127.0.0.1 \
  -p 5432 \
  -U postgres \
  -d solidity_security \
  --no-owner \
  --no-acl \
  -v \
  backup.sql
```

See [Platform Development Standards](/Users/pwner/Git/ABS/docs/PLATFORM-DEVELOPMENT-STANDARDS.md#database-management-and-recovery) for complete backup and recovery procedures.

---

## Related Documentation

- [Platform Development Standards](/Users/pwner/Git/ABS/docs/PLATFORM-DEVELOPMENT-STANDARDS.md)
- [API Service README](/Users/pwner/Git/ABS/blocksecops-api-service/README.md)
- [Alembic Migrations](/Users/pwner/Git/ABS/blocksecops-api-service/alembic/versions/)

---

**Document Version:** 1.1.0
**Last Updated:** October 18, 2025
**Maintained By:** BlockSecOps Team
