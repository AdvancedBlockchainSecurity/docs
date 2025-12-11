# BlockSecOps Database Schema

**Database:** PostgreSQL 15.4
**Database Name:** `solidity_security`
**Schema:** `public`
**Timezone:** UTC

## Table of Contents

1. [Overview](#overview)
2. [Entity Relationship Diagram](#entity-relationship-diagram)
3. [Tables](#tables)
4. [ENUM Types](#enum-types)
5. [Indexes](#indexes)
6. [Relationships](#relationships)

---

## Overview

The BlockSecOps database supports a comprehensive smart contract security scanning platform with:

- **Multi-language support:** 21+ blockchain languages including Solidity, Vyper, Rust, Move, Cairo
- **Multi-file contracts:** Support for complex projects with multiple source files
- **Project organization:** Group related contracts into projects
- **User authentication:** Supabase Auth with ES256 JWT tokens and JWKS verification
- **Security scanning:** Vulnerability detection with severity classification and multi-scanner support
- **Scanner tracking:** Attribution and categorization of vulnerabilities by detection tool
- **Saved searches:** User-saved search queries with JSONB parameters
- **User preferences:** Customizable notification settings and UI preferences
- **Performance optimization:** Specialized indexes including GIN, composite, and partial indexes
- **Audit tracking:** Full timestamps and status tracking
- **Intelligence layer:** Enrichment and fingerprinting for vulnerability deduplication
- **Pattern matching:** Vulnerability pattern classification across 4 ecosystems (Solidity/EVM, Vyper, Solana, Cairo)
- **Deduplication:** Cross-scanner finding deduplication
- **Tier-based quotas:** User quotas with monthly scan limits and tier-based priority
- **Priority queue:** Scan priority system for tier-based queue processing
- **Wallet authentication:** MetaMask/WalletConnect SIWE authentication (Phase 3.3)
- **Enterprise features:** Organizations, RBAC, webhooks, API keys, audit logs (Phase 4.5)
- **x402 payments:** Pay-per-scan with USDC, scan credits, payment transactions (Phase 3.4)
- **Scanner results:** Specialized result tables for gas analysis, fuzzing, formal verification, code quality (Phase 3)
- **Contract analysis:** Parsed function, event, and state variable definitions from contracts
- **Activity logging:** User activity tracking for uploads, scans, payments, and credit usage (Phase 3.1b)

**Total Tables:** 33 (excluding alembic_version)

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
└───────────────────┘ └─────┬─────┘  └──────────┬───────────┘
                            │                   │
                            │ 1:N               │ M:1 (pattern_id)
                            │                   │
                      ┌─────▼──────────────┐    │           ┌──────────────────────┐
                      │  vulnerabilities   │────┼──────────►│ vulnerability_       │
                      └─────┬──────────────┘    │           │ patterns             │
                            │                   │           └──────────┬───────────┘
                            │ M:1 (dedup)       │                      │
                            │                   │                      │ 1:N
                            │                   └─────────────────┐    │
                            │                                     │    │
                      ┌─────▼──────────────┐                      │    │
                      │ deduplication_     │                      │    │
                      │ groups             │                      │    │
                      └────────────────────┘                      │    │
                            ▲                                     │    │
                            │                                     ▼    ▼
                            │                              ┌──────────────────┐
                            └──────────────────────────────│ pattern_tool_    │
                                                           │ mappings         │
                                                           └──────────────────┘
```

**Intelligence Layer Tables (Phase 1-4 - Nov 1, 2025)**:
- `vulnerability_patterns`: 397 standardized patterns across 4 ecosystems
- `pattern_tool_mappings`: 397 scanner detector → pattern mappings (12 scanners)
- `deduplication_groups`: Cross-scanner finding deduplication groups

---

## Tables

### `users`

User accounts with Supabase authentication and tier tracking (Phase 3.1a - Migration Complete, November 13, 2025).

**Authentication**: ✅ Migrated to Supabase Auth (ES256 JWT with JWKS verification)

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique user identifier (internal) |
| `email` | VARCHAR(255) | NOT NULL, UNIQUE | User email address |
| `hashed_password` | VARCHAR(255) | NULLABLE | Bcrypt hashed password (legacy, NULL for Supabase users) |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true | Account active status |
| `is_superuser` | BOOLEAN | NOT NULL, DEFAULT false | Admin privileges flag |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Account creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |
| `tier` | VARCHAR(20) | NOT NULL, DEFAULT 'free', INDEX | User tier (free, pro, enterprise, enterprise_broker) |
| `tier_updated_at` | TIMESTAMPTZ | NULLABLE, DEFAULT now() | Last tier change timestamp |
| `supabase_user_id` | UUID | NULLABLE, UNIQUE, INDEX | **Supabase Auth user identifier (PRIMARY auth key)** |
| `stripe_customer_id` | VARCHAR(255) | NULLABLE | Stripe customer identifier for billing |
| `stripe_subscription_id` | VARCHAR(255) | NULLABLE | Stripe subscription identifier |
| `wallet_address` | VARCHAR(42) | NULLABLE, UNIQUE, INDEX | Ethereum wallet address (Phase 3.3) |
| `wallet_nonce` | VARCHAR(64) | NULLABLE | SIWE nonce for signature verification |
| `wallet_linked_at` | TIMESTAMPTZ | NULLABLE | Timestamp when wallet was linked |
| `ens_name` | VARCHAR(255) | NULLABLE, INDEX | ENS domain name (e.g., vitalik.eth) |

**Indexes:**
- `ix_users_email` (UNIQUE) on `email`
- `ix_users_tier` on `tier`
- `ix_users_supabase_user_id` (UNIQUE) on `supabase_user_id`
- `ix_users_wallet_address` (UNIQUE) on `wallet_address`
- `ix_users_ens_name` on `ens_name`

**Relationships:**
- One-to-many with `sessions`
- One-to-many with `contracts`
- One-to-many with `scans`
- One-to-many with `projects`
- One-to-one with `user_quotas`
- One-to-one with `scan_credits` (Phase 3.4)
- One-to-many with `payment_transactions` (Phase 3.4)
- One-to-many with `organization_members` (Phase 4.5)
- One-to-many with `webhooks` (Phase 4.5)
- One-to-many with `api_keys` (Phase 4.5)
- One-to-many with `audit_logs` (Phase 4.5)
- One-to-many with `user_activity_logs` (Phase 3.1b)

---

### `sessions`

**⚠️ DEPRECATED** - Custom authentication sessions (replaced by Supabase Auth, November 13, 2025).

This table is no longer used. Authentication is now handled by Supabase Auth with JWT tokens stored in localStorage on the client.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique session identifier (legacy) |
| `user_id` | UUID | NOT NULL, FK → users.id | Associated user (legacy) |
| `token` | VARCHAR(500) | NOT NULL, UNIQUE | JWT access token (legacy, HS256) |
| `refresh_token` | VARCHAR(500) | UNIQUE, NULLABLE | JWT refresh token (legacy) |
| `expires_at` | TIMESTAMPTZ | NOT NULL | Token expiration time (legacy) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Session creation time (legacy) |
| `is_revoked` | BOOLEAN | NOT NULL, DEFAULT false | Session revocation status (legacy) |

**Indexes:**
- `ix_sessions_user_id` on `user_id`
- `ix_sessions_token` (UNIQUE) on `token`
- `ix_sessions_refresh_token` (UNIQUE) on `refresh_token`

**Relationships:**
- Many-to-one with `users` (user_id)

**Migration Notes:**
- Table can be dropped after confirming all users migrated to Supabase
- No new records are created after Phase 3.1a migration
- Existing records can be safely deleted

---

### `user_quotas`

User quota tracking for tier-based limits (Phase 3.1a - Freemium Model). Auto-created via trigger when user is created.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique quota identifier |
| `user_id` | UUID | NOT NULL, UNIQUE, FK → users.id ON DELETE CASCADE | Associated user |
| `tier` | VARCHAR(20) | NOT NULL, DEFAULT 'free', INDEX | Current tier (synced from users.tier) |
| `monthly_scan_limit` | INTEGER | NOT NULL, DEFAULT 10 | Monthly scan limit (-1 = unlimited) |
| `monthly_scans_used` | INTEGER | NOT NULL, DEFAULT 0 | Scans used this month |
| `max_files_per_scan` | INTEGER | NOT NULL, DEFAULT 25 | Maximum files per scan (-1 = unlimited) |
| `scan_priority` | INTEGER | NOT NULL, DEFAULT 25 | Scan queue priority (0=highest, 100=lowest) |
| `webhooks_enabled` | BOOLEAN | NOT NULL, DEFAULT false | Webhooks feature enabled |
| `api_access_enabled` | BOOLEAN | NOT NULL, DEFAULT false | API access enabled |
| `result_retention_days` | INTEGER | NOT NULL, DEFAULT 30 | Scan result retention period |
| `quota_reset_at` | TIMESTAMPTZ | NOT NULL, DEFAULT next month | Next quota reset date |
| `last_scan_at` | TIMESTAMPTZ | NULLABLE | Last scan timestamp |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Quota record creation |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_user_quotas_user_id` on `user_id`
- `ix_user_quotas_tier` on `tier`

**Relationships:**
- One-to-one with `users` (user_id, CASCADE DELETE)

**Tier Limits (Phase 3.1a - All Enforced as of November 15, 2025)**:
- **Free**: 10 scans/month, 25 files/scan, 1 MB files (5 MB archives), 30-day retention, priority=25
- **Pro**: Unlimited scans, 100 files/scan, 5 MB files (25 MB archives), 365-day retention, priority=50, webhooks + API
- **Enterprise**: Unlimited scans, unlimited files, 10 MB files (50 MB archives), 730-day retention, priority=75, all features
- **Enterprise Broker**: Unlimited scans, unlimited files, 10 MB files (50 MB archives), 730-day retention, priority=100 (highest)

**Auto-Creation Trigger:**
- Trigger function `create_user_quota()` automatically creates quota record on user insert
- Quota limits set based on user's initial tier
- Monthly reset handled by `quota_reset_at` timestamp

**Quota Enforcement (Phase 3.1a Week 2 - November 14, 2025):**
- Enforced at scan creation endpoint (`POST /api/v1/scans`)
- Checks `monthly_scans_used >= monthly_scan_limit` before allowing scan
- Returns HTTP 402 Payment Required when quota exceeded
- Increments `monthly_scans_used` after successful scan creation
- Updates `last_scan_at` timestamp on each scan

**Quota Exceeded Error Response (HTTP 402):**
```json
{
  "detail": {
    "error": "quota_exceeded",
    "message": "You've used all 10 scans for this month",
    "tier": "free",
    "scans_used": 10,
    "scan_limit": 10,
    "scans_remaining": 0,
    "reset_date": "2025-12-01T00:00:00+00:00",
    "days_until_reset": 17,
    "upgrade_url": "/pricing",
    "upgrade_message": "Upgrade to Pro for unlimited scans or wait until your quota resets"
  }
}
```

**Reset Date Calculation:**
- Quota resets on 1st of each month at 00:00 UTC
- Next reset date calculated as: `datetime(year, month+1, 1, 0, 0, 0, tzinfo=UTC)`
- Handles December edge case: `datetime(year+1, 1, 1, 0, 0, 0, tzinfo=UTC)`

**File Upload Enforcement (Phase 3.1a - November 15, 2025):**

Enforced at upload endpoint (`POST /api/v1/upload`):

1. **File Size Limits** (tier-based):
   - Free: 1 MB per file, 5 MB archives
   - Pro: 5 MB per file, 25 MB archives
   - Enterprise: 10 MB per file, 50 MB archives
   - Returns HTTP 413 if file size exceeds tier limit

2. **Files-per-Scan Limits** (from `max_files_per_scan` column):
   - Free: 25 files max per archive
   - Pro: 100 files max per archive
   - Enterprise/Enterprise Broker: Unlimited (-1)
   - Returns HTTP 402 if archive exceeds file count limit

3. **Language Validation**:
   - Only Solidity (`.sol`), Vyper (`.vy`), Rust/Solana (`.rs`), Cairo (`.cairo`) supported
   - Archives: `.zip`, `.tar`, `.tar.gz`, `.tgz`
   - Returns HTTP 400 for unsupported file types

**Error Response Examples:**

File Too Large (HTTP 413):
```json
{
  "detail": {
    "error": "file_too_large",
    "message": "File size (2.5 MB) exceeds free tier limit of 1 MB for files",
    "tier": "free",
    "file_size_mb": 2.5,
    "max_size_mb": 1,
    "upgrade_url": "/pricing"
  }
}
```

Too Many Files (HTTP 402):
```json
{
  "detail": {
    "error": "too_many_files",
    "message": "Archive contains 30 files, exceeding free tier limit of 25 files per scan",
    "tier": "free",
    "file_count": 30,
    "max_files_per_scan": 25,
    "upgrade_url": "/pricing"
  }
}
```

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
| ~~`is_project`~~ | ~~BOOLEAN~~ | ~~NOT NULL, DEFAULT false~~ | **REMOVED** - Full project structure flag (planned for future migration) |
| `main_file_path` | VARCHAR(500) | NULLABLE | Path to main contract file |
| `file_count` | INTEGER | NOT NULL, DEFAULT 1 | Number of source files |
| `total_lines_of_code` | INTEGER | NOT NULL, DEFAULT 0 | Total LOC across all files |
| `language` | contract_language | NOT NULL | Programming language |
| `compiler_version` | VARCHAR(50) | NULLABLE | Compiler version used |
| `language_metadata` | JSONB | NULLABLE | Language-specific metadata |
| `framework` | VARCHAR(50) | NULLABLE, INDEX | Framework type (foundry, hardhat, plain) - Phase 3.2 |
| `framework_config` | JSONB | NULLABLE | Parsed framework configuration - Phase 3.2 |
| `status` | contract_status | NOT NULL | Current processing status |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Upload timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_contracts_user_id` on `user_id`
- `ix_contracts_address` on `address`
- `ix_contracts_language` on `language`
- `idx_contracts_framework` on `framework` (partial, WHERE framework IS NOT NULL) - Phase 3.2

**Framework Support (Phase 3.2 - November 25, 2025)**:

The `framework` and `framework_config` columns enable native support for Foundry and Hardhat projects:

**Framework Types**:
- `foundry` - Foundry projects (detected by `foundry.toml`)
- `hardhat` - Hardhat projects (detected by `hardhat.config.js` or `hardhat.config.ts`)
- `plain` - Plain Solidity/Vyper files without framework

**Framework Config Structure (JSONB)**:

For Foundry projects:
```json
{
  "solc_version": "0.8.20",
  "src_dir": "src",
  "test_dir": "test",
  "out_dir": "out",
  "libs": ["lib"],
  "remappings": [
    "@openzeppelin/=lib/openzeppelin-contracts/",
    "forge-std/=lib/forge-std/src/"
  ],
  "optimizer_enabled": true,
  "optimizer_runs": 200,
  "via_ir": false,
  "evm_version": "paris"
}
```

For Hardhat projects:
```json
{
  "solc_version": "0.8.20",
  "sources_path": "./contracts",
  "tests_path": "./test",
  "optimizer_enabled": true,
  "optimizer_runs": 200,
  "evm_version": "paris",
  "dependencies": {
    "@openzeppelin/contracts": "^5.0.0"
  }
}
```

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
| `priority` | INTEGER | NOT NULL, DEFAULT 50, INDEX | Scan priority (lower = higher priority). Enterprise=5, Pro=25, Free=50 |
| `scanners_used` | ARRAY(VARCHAR(50)) | NULLABLE | Array of scanner IDs used in this scan |
| `scan_config` | JSONB | NULLABLE, DEFAULT '{}' | Scanner configuration parameters |
| `duration_seconds` | INTEGER | NULLABLE | Scan duration in seconds |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Scan queue time |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last status update |

**Indexes:**
- `ix_scans_contract_id` on `contract_id`
- `ix_scans_user_id` on `user_id`
- `ix_scans_priority` on `priority` (for priority queue ordering)
- `ix_scans_status_priority` on `(status, priority)` (composite index for queue polling)

**Relationships:**
- Many-to-one with `contracts` (contract_id)
- Many-to-one with `users` (user_id)
- One-to-many with `vulnerabilities` (CASCADE DELETE)
- One-to-many with `code_quality_findings` (CASCADE DELETE)
- One-to-many with `gas_analysis_findings` (CASCADE DELETE)
- One-to-many with `formal_verification_results` (CASCADE DELETE)
- One-to-many with `fuzzing_results` (CASCADE DELETE)
- One-to-many with `payment_transactions` (SET NULL on delete)
- One-to-many with `credit_transactions` (SET NULL on delete)

**Cascade Delete Behavior** (December 9, 2025):
When a scan is deleted via `DELETE /api/v1/scans/{scan_id}` or batch delete:
- All associated `vulnerabilities` records are automatically deleted
- All associated specialized result records (`code_quality_findings`, `gas_analysis_findings`, `formal_verification_results`, `fuzzing_results`) are automatically deleted
- `payment_transactions.scan_id` and `credit_transactions.scan_id` are set to NULL (preserving billing/credit history)

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
| `detector_id` | VARCHAR(200) | NULLABLE, INDEX | Tool-specific detector identifier (e.g., "reentrancy-eth") (Phase 4D) |
| `file_path` | VARCHAR(500) | NULLABLE, INDEX | Source file path where vulnerability was detected (Phase 4D) |
| `function_name` | VARCHAR(200) | NULLABLE, INDEX | Function name where vulnerability exists (Phase 4D) |
| `contract_name` | VARCHAR(200) | NULLABLE, INDEX | Contract name where vulnerability exists (Phase 4D) |
| `category` | VARCHAR(100) | NULLABLE | Vulnerability type category (e.g., reentrancy, access_control) |
| `confidence` | NUMERIC(3,2) | NULLABLE | Scanner confidence score (0.0 to 1.0) |
| `pattern_id` | VARCHAR(20) | NULLABLE | FK → vulnerability_patterns.id - Pattern classification reference |
| `pattern_code` | VARCHAR(20) | NULLABLE | Pattern code (e.g., 'SWC-107', 'SLITHER-REENTRANCY') |
| `classification_confidence` | DOUBLE PRECISION | NULLABLE | Pattern match confidence score (0.0 to 1.0) |
| `classification_method` | VARCHAR(20) | NULLABLE | Classification method used ('exact', 'fuzzy', 'ml') |
| `fingerprint_code` | VARCHAR(64) | NULLABLE | SHA256 hash of normalized code snippet |
| `fingerprint_ast` | VARCHAR(64) | NULLABLE | SHA256 hash of AST structure |
| `fingerprint_location` | VARCHAR(64) | NULLABLE | Hash of file path + line number |
| `fingerprint_location_fuzzy` | VARCHAR(64) | NULLABLE | Hash of file path + fuzzy line range (±3 lines) |
| `fingerprint_semantic` | VARCHAR(64) | NULLABLE | Semantic similarity fingerprint |
| `fingerprint_composite` | VARCHAR(64) | NULLABLE | Composite hash of multiple fingerprints |
| `deduplication_group_id` | UUID | NULLABLE | FK → deduplication_groups.id - Group of duplicate findings |
| `is_primary` | BOOLEAN | NOT NULL, DEFAULT true | Primary instance in deduplication group |
| `duplicate_count` | INTEGER | NOT NULL, DEFAULT 0 | Number of duplicate findings |
| `deduplication_strategy` | VARCHAR(20) | NULLABLE | Strategy used for deduplication ('exact', 'fuzzy', 'semantic') |
| `similarity_score` | DOUBLE PRECISION | NULLABLE | Similarity score with primary finding (0.0 to 1.0) |
| `false_positive_score` | DOUBLE PRECISION | NULLABLE | Likelihood of being false positive (0.0 to 1.0) |
| `false_positive_reasons` | TEXT[] | NULLABLE | Array of reasons for FP classification |
| `scanner_confidence` | DOUBLE PRECISION | NULLABLE | Tool-specific confidence score |
| `tool_consensus_score` | DOUBLE PRECISION | NULLABLE | Consensus score across multiple scanners |
| `first_seen` | TIMESTAMPTZ | NULLABLE | First detection timestamp across scans |
| `last_seen` | TIMESTAMPTZ | NULLABLE | Most recent detection timestamp |
| `occurrence_count` | INTEGER | NOT NULL, DEFAULT 1 | Number of times detected across scans |
| `was_fixed` | BOOLEAN | NOT NULL, DEFAULT false | Whether vulnerability was previously fixed |
| `reintroduced` | BOOLEAN | NOT NULL, DEFAULT false | Whether vulnerability was reintroduced after fix |
| `user_classification` | VARCHAR(20) | NULLABLE | User override classification |
| `user_feedback` | TEXT | NULLABLE | User feedback on classification |
| `fix_verified` | BOOLEAN | NOT NULL, DEFAULT false | Whether fix has been verified |
| `fix_verified_at` | TIMESTAMPTZ | NULLABLE | Timestamp of fix verification |
| `fix_verified_by` | UUID | NULLABLE | User who verified the fix |
| `raw_output` | JSONB | NULLABLE | Raw scanner output |
| `normalization_version` | VARCHAR(20) | NULLABLE | Version of normalization logic used |
| `detected_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Detection timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last status update |

**Indexes:**
- `ix_vulnerabilities_scan_id` on `scan_id`
- `ix_vulnerabilities_contract_id` on `contract_id`
- `ix_vulnerabilities_severity` on `severity`
- `ix_vulnerabilities_scanner_id` on `scanner_id` (Migration 004)
- `ix_vulnerabilities_category` on `category` (Migration 004)
- `ix_vulnerabilities_detector_id` on `detector_id` (Phase 4D, Migration 005)
- `ix_vulnerabilities_file_path` on `file_path` (Phase 4D, Migration 005)
- `ix_vulnerabilities_function_name` on `function_name` (Phase 4D, Migration 005)
- `ix_vulnerabilities_contract_name` on `contract_name` (Phase 4D, Migration 005)
- `ix_vulnerabilities_location_lookup` on `(contract_name, file_path, function_name)` (Phase 4D, Migration 005)
- `ix_vulnerabilities_pattern_id` on `pattern_id` (Phase 4D)
- `ix_vulnerabilities_pattern_code` on `pattern_code` (Phase 4D)
- `ix_vulnerabilities_user_classification` on `user_classification` (Phase 4D)
- `ix_vulnerabilities_fingerprint_code` on `fingerprint_code` (Phase 4D)
- `ix_vulnerabilities_fingerprint_composite` on `fingerprint_composite` (Phase 4D)
- `ix_vulnerabilities_fingerprint_location_fuzzy` on `fingerprint_location_fuzzy` (Phase 4D)
- `ix_vulnerabilities_deduplication_group_id` on `deduplication_group_id` (Phase 4D)

**Relationships:**
- Many-to-one with `scans` (scan_id, CASCADE DELETE - vulnerabilities are deleted when parent scan is deleted)
- Many-to-one with `contracts` (contract_id)

---

### `gas_analysis_findings`

Gas optimization findings from scanner analysis (Phase 3 - Advanced Scanners).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique finding identifier |
| `scan_id` | UUID | NOT NULL, FK → scans.id ON DELETE CASCADE | Associated scan |
| `scanner_id` | VARCHAR(50) | NOT NULL | Scanner that detected this (e.g., "4naly3er") |
| `function_name` | VARCHAR(255) | NOT NULL | Function with gas issue |
| `gas_cost` | INTEGER | NOT NULL | Current gas cost |
| `optimization_level` | VARCHAR(20) | NOT NULL | Optimization priority (low, medium, high) |
| `optimization_suggestion` | TEXT | NOT NULL | Suggested optimization |
| `potential_savings` | INTEGER | NOT NULL | Potential gas savings |
| `location` | JSONB | NOT NULL | Location information (file, line, column) |
| `code_example` | TEXT | NULLABLE | Example code for optimization |
| `contract_id` | UUID | NULLABLE, FK → contracts.id ON DELETE CASCADE | Associated contract |
| `detector_id` | VARCHAR(200) | NULLABLE | Tool-specific detector ID |
| `file_path` | VARCHAR(500) | NULLABLE | Source file path |
| `contract_name` | VARCHAR(200) | NULLABLE | Contract name |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |

**Indexes:**
- `ix_gas_analysis_findings_scan_id` on `scan_id`
- `ix_gas_analysis_findings_scanner_id` on `scanner_id`
- `ix_gas_analysis_findings_function_name` on `function_name`
- `ix_gas_analysis_findings_optimization_level` on `optimization_level`

**Relationships:**
- Many-to-one with `scans` (scan_id, CASCADE DELETE)
- Many-to-one with `contracts` (contract_id, CASCADE DELETE)

---

### `code_quality_findings`

Code quality and linting results from tools like Solhint (Phase 3 - Scanner Integration).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique finding identifier |
| `scan_id` | UUID | NOT NULL, FK → scans.id ON DELETE CASCADE | Associated scan |
| `scanner_id` | VARCHAR(50) | NOT NULL | Scanner (e.g., "solhint") |
| `severity` | VARCHAR(20) | NOT NULL | Severity level |
| `category` | VARCHAR(50) | NOT NULL | Finding category |
| `title` | TEXT | NOT NULL | Finding title |
| `description` | TEXT | NOT NULL | Finding description |
| `location` | JSONB | NOT NULL | Location information |
| `fix_suggestion` | TEXT | NULLABLE | Suggested fix |
| `rule_id` | VARCHAR(100) | NOT NULL | Linter rule ID |
| `rule_url` | TEXT | NULLABLE | Link to rule documentation |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |

**Indexes:**
- `ix_code_quality_findings_scan_id` on `scan_id`
- `ix_code_quality_findings_scanner_id` on `scanner_id`
- `ix_code_quality_findings_severity` on `severity`
- `ix_code_quality_findings_category` on `category`

**Relationships:**
- Many-to-one with `scans` (scan_id, CASCADE DELETE)

---

### `fuzzing_results`

Fuzzing test results from Echidna, Medusa, and other fuzz testers (Phase 3 - Advanced Tools).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique result identifier |
| `scan_id` | UUID | NOT NULL, FK → scans.id ON DELETE CASCADE | Associated scan |
| `scanner_id` | VARCHAR(50) | NOT NULL | Scanner (e.g., "echidna", "medusa") |
| `test_name` | VARCHAR(255) | NOT NULL | Fuzz test name |
| `status` | VARCHAR(20) | NOT NULL | Test status (passed, failed, timeout) |
| `executions` | INTEGER | NOT NULL | Number of test executions |
| `coverage_percentage` | DOUBLE PRECISION | NOT NULL | Code coverage percentage |
| `edge_cases_found` | JSONB | NOT NULL, DEFAULT '[]' | Array of edge cases found |
| `failure_trace` | TEXT | NULLABLE | Failure trace if test failed |
| `seed` | INTEGER | NULLABLE | Random seed used |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |

**Indexes:**
- `ix_fuzzing_results_scan_id` on `scan_id`
- `ix_fuzzing_results_scanner_id` on `scanner_id`
- `ix_fuzzing_results_status` on `status`
- `ix_fuzzing_results_test_name` on `test_name`

**Relationships:**
- Many-to-one with `scans` (scan_id, CASCADE DELETE)

---

### `formal_verification_results`

Formal verification proof results from Halmos, Certora (Phase 3 - Formal Verification).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique result identifier |
| `scan_id` | UUID | NOT NULL, FK → scans.id ON DELETE CASCADE | Associated scan |
| `scanner_id` | VARCHAR(50) | NOT NULL | Scanner (e.g., "halmos", "certora") |
| `property_name` | VARCHAR(255) | NOT NULL | Property being verified |
| `status` | VARCHAR(20) | NOT NULL | Verification status (proved, violated, timeout) |
| `proof_type` | VARCHAR(50) | NOT NULL | Type of proof (invariant, assertion, etc.) |
| `description` | TEXT | NOT NULL | Property description |
| `counterexample` | TEXT | NULLABLE | Counterexample if property violated |
| `verification_time` | DOUBLE PRECISION | NOT NULL | Verification time in seconds |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |

**Indexes:**
- `ix_formal_verification_results_scan_id` on `scan_id`
- `ix_formal_verification_results_scanner_id` on `scanner_id`
- `ix_formal_verification_results_status` on `status`
- `ix_formal_verification_results_proof_type` on `proof_type`

**Relationships:**
- Many-to-one with `scans` (scan_id, CASCADE DELETE)

---

### `contract_functions`

Parsed function definitions from smart contracts (Contract Analysis).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique function identifier |
| `contract_id` | UUID | NOT NULL, FK → contracts.id ON DELETE CASCADE | Parent contract |
| `name` | VARCHAR(255) | NOT NULL | Function name |
| `selector` | VARCHAR(10) | NULLABLE | Function selector (4 bytes) |
| `visibility` | VARCHAR(20) | NOT NULL | Visibility (public, private, internal, external) |
| `state_mutability` | VARCHAR(20) | NULLABLE | Mutability (pure, view, payable, nonpayable) |
| `is_constructor` | BOOLEAN | NOT NULL, DEFAULT false | Is constructor |
| `is_fallback` | BOOLEAN | NOT NULL, DEFAULT false | Is fallback function |
| `is_receive` | BOOLEAN | NOT NULL, DEFAULT false | Is receive function |
| `parameters` | JSONB | NULLABLE | Function parameters |
| `return_types` | JSONB | NULLABLE | Return types |
| `modifiers` | JSONB | NULLABLE | Applied modifiers |
| `start_line` | INTEGER | NULLABLE | Start line number |
| `end_line` | INTEGER | NULLABLE | End line number |
| `natspec` | JSONB | NULLABLE | NatSpec documentation |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |

**Indexes:**
- `idx_functions_contract` on `contract_id`
- `idx_functions_name` on `name`
- `idx_functions_selector` on `selector`
- `idx_functions_visibility` on `visibility`

**Relationships:**
- Many-to-one with `contracts` (contract_id, CASCADE DELETE)

---

### `contract_events`

Parsed event definitions from smart contracts (Contract Analysis).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique event identifier |
| `contract_id` | UUID | NOT NULL, FK → contracts.id ON DELETE CASCADE | Parent contract |
| `name` | VARCHAR(255) | NOT NULL | Event name |
| `signature` | VARCHAR(500) | NULLABLE | Event signature |
| `topic0` | VARCHAR(66) | NULLABLE | Event topic0 (keccak256 hash) |
| `parameters` | JSONB | NOT NULL | Event parameters |
| `anonymous` | BOOLEAN | NOT NULL, DEFAULT false | Is anonymous event |
| `start_line` | INTEGER | NULLABLE | Line number |
| `natspec` | JSONB | NULLABLE | NatSpec documentation |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |

**Indexes:**
- `idx_events_contract` on `contract_id`
- `idx_events_name` on `name`
- `idx_events_topic0` on `topic0`

**Relationships:**
- Many-to-one with `contracts` (contract_id, CASCADE DELETE)

---

### `contract_state_variables`

Parsed state variable definitions from smart contracts (Contract Analysis).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique variable identifier |
| `contract_id` | UUID | NOT NULL, FK → contracts.id ON DELETE CASCADE | Parent contract |
| `name` | VARCHAR(255) | NOT NULL | Variable name |
| `type_name` | VARCHAR(500) | NOT NULL | Solidity type (uint256, address, etc.) |
| `visibility` | VARCHAR(20) | NOT NULL | Visibility (public, private, internal) |
| `mutability` | VARCHAR(20) | NULLABLE | Mutability (constant, immutable) |
| `storage_slot` | INTEGER | NULLABLE | Storage slot position |
| `initial_value` | TEXT | NULLABLE | Initial value if set |
| `start_line` | INTEGER | NULLABLE | Line number |
| `natspec` | JSONB | NULLABLE | NatSpec documentation |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |

**Indexes:**
- `idx_variables_contract` on `contract_id`
- `idx_variables_name` on `name`
- `idx_variables_type` on `type_name`
- `idx_variables_visibility` on `visibility`

**Relationships:**
- Many-to-one with `contracts` (contract_id, CASCADE DELETE)

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

### `user_activity_logs`

User activity log entries for tracking uploads, scans, payments, and credit usage (Phase 3.1b - Task 21, December 10, 2025).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique activity identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Associated user |
| `activity_type` | VARCHAR(50) | NOT NULL, INDEX | Activity type (see enum below) |
| `description` | VARCHAR(500) | NOT NULL | Human-readable description |
| `contract_id` | UUID | NULLABLE, FK → contracts.id ON DELETE SET NULL | Related contract (for navigation) |
| `scan_id` | UUID | NULLABLE, FK → scans.id ON DELETE SET NULL | Related scan (for navigation) |
| `scanner_type` | VARCHAR(50) | NULLABLE | Scanner tool name (when applicable) |
| `scan_status` | VARCHAR(20) | NULLABLE | Scan completion status (when applicable) |
| `credits_used` | INTEGER | NOT NULL, DEFAULT 0 | Credits consumed (positive or negative) |
| `payment_amount` | NUMERIC(10,2) | NULLABLE | Payment amount (for payment activities) |
| `payment_currency` | VARCHAR(10) | NULLABLE | Payment currency code (USD, USDC) |
| `activity_metadata` | JSONB | NULLABLE | Additional context data |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Activity timestamp |

**Activity Types:**
- `file_upload` - File uploaded to platform
- `contract_created` - New contract created
- `contract_deleted` - Contract deleted
- `scan_started` - Security scan initiated
- `scan_completed` - Security scan completed successfully
- `scan_failed` - Security scan failed
- `payment` - Payment transaction
- `credit_purchase` - Credits purchased
- `credit_used` - Credits consumed for scan

**Indexes:**
- `ix_user_activity_logs_user_id` on `user_id`
- `ix_user_activity_logs_activity_type` on `activity_type`
- `ix_user_activity_logs_created_at` on `created_at`
- `ix_user_activity_logs_user_id_created_at` composite on `(user_id, created_at)` for efficient user queries

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `contracts` (contract_id, SET NULL on delete)
- Many-to-one with `scans` (scan_id, SET NULL on delete)

**API Endpoint:**
- `GET /api/v1/users/me/activity` - Returns paginated activity log with summary statistics

---

### `vulnerability_patterns`

Standard vulnerability pattern definitions for classification and matching (Phase 4D).

**Pattern Code Format (Updated 2025-10-28):** All pattern codes use the `BVD-` prefix to denote **Blockchain Vulnerability Database** classification.
- **Format**: `BVD-{CATEGORY}-{NUMBER}` (e.g., "BVD-EVM-REE-001", "BVD-EVM-ACC-001")
- **Category Codes**: REE (Reentrancy), ACC (Access Control), INT (Integer), ORA (Oracle), TOK (Token), etc.
- **Historical Note**: Prior to 2025-10-28, patterns used format without BVD prefix (e.g., "REE-001")

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | VARCHAR(20) | PRIMARY KEY | Pattern identifier (e.g., "BVD-EVM-REE-001", "BVD-EVM-ACC-001") |
| `name` | VARCHAR(200) | NOT NULL | Pattern name (e.g., "Reentrancy Attack") |
| `description` | TEXT | NOT NULL | Detailed pattern description |
| `category` | VARCHAR(50) | NOT NULL, INDEX | Vulnerability category (e.g., "reentrancy", "access_control") |
| `severity` | VARCHAR(20) | NOT NULL, INDEX | Default severity level |
| `swc_id` | VARCHAR(20) | NULLABLE, INDEX | Smart Contract Weakness Classification ID |
| `cwe_id` | VARCHAR(20) | NULLABLE, INDEX | Common Weakness Enumeration ID |
| `owasp_category` | VARCHAR(100) | NULLABLE | OWASP Top 10 category |
| `remediation` | TEXT | NULLABLE | Remediation guidance |
| `fix_examples` | JSONB | NULLABLE | JSON array of fix examples (supports both strings and structured objects with language/vulnerable_code/fixed_code fields) |
| `references` | JSONB | NULLABLE | JSON array of reference URLs |
| `detection_methods` | VARCHAR(50)[] | NULLABLE | Array of detection methods |
| `false_positive_rate` | DOUBLE PRECISION | DEFAULT 0.0 | Historical false positive rate |
| `affected_languages` | VARCHAR(20)[] | NOT NULL, GIN INDEX | Array of affected languages |
| `semantic_description` | TEXT | NULLABLE | Semantic description for ML matching |
| `keywords` | TEXT[] | NULLABLE, GIN INDEX | Keywords for text matching |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true, INDEX | Active status flag |

**Indexes:**
- `vulnerability_patterns_pkey` (PRIMARY KEY) on `id`
- `ix_vuln_patterns_category` on `category`
- `ix_vuln_patterns_severity` on `severity`
- `ix_vuln_patterns_swc_id` on `swc_id`
- `ix_vuln_patterns_cwe_id` on `cwe_id`
- `ix_vuln_patterns_is_active` on `is_active`
- `ix_vuln_patterns_languages` (GIN) on `affected_languages`
- `ix_vuln_patterns_keywords` (GIN) on `keywords`

**Relationships:**
- One-to-many with `pattern_tool_mappings`
- Referenced by `vulnerabilities.pattern_id`

**Seed Data:** **352 vulnerability patterns** (updated 2025-11-02, Phase 6.7 migration complete) - 31 legacy duplicate patterns removed

**Pattern Distribution (352 total patterns across 4 ecosystems, 100% BVD compliant)**:

**Solidity/EVM Patterns (171 patterns)**:
- Reentrancy (15 patterns): BVD-EVM-REE-001 through BVD-EVM-REE-015
- Access Control (18 patterns): BVD-EVM-ACC-001 through BVD-EVM-ACC-018
- Integer/Arithmetic (12 patterns): BVD-EVM-INT-001 through BVD-EVM-INT-012
- External Calls (10 patterns): BVD-EVM-EXT-001 through BVD-EVM-EXT-010
- State Variables (8 patterns): BVD-EVM-STA-001 through BVD-EVM-STA-008
- Gas Optimization (15 patterns): BVD-EVM-GAS-001 through BVD-EVM-GAS-015
- Plus 124 additional patterns across 35+ categories

**Vyper Patterns (99 patterns)**:
- Reentrancy (12 patterns): BVD-VYPER-REE-001 through BVD-VYPER-REE-012
- Access Control (8 patterns): BVD-VYPER-ACC-001 through BVD-VYPER-ACC-008
- Integer Issues (6 patterns): BVD-VYPER-INT-001 through BVD-VYPER-INT-006
- Plus 73 additional patterns

**Solana/Rust Patterns (82 patterns)**:
- Access Control (15 patterns): BVD-SOLANA-ACC-001 through BVD-SOLANA-ACC-015
- Integer Overflow (8 patterns): BVD-SOLANA-INT-001 through BVD-SOLANA-INT-008
- PDA Issues (10 patterns): BVD-SOLANA-PDA-001 through BVD-SOLANA-PDA-010
- Plus 49 additional patterns

**Cairo/StarkNet Patterns (14 patterns)** ✨ NEW:
- Access Control (2 patterns): BVD-CAIRO-ACC-001, BVD-CAIRO-ACC-002
- Layer 2 Security (1 pattern): BVD-CAIRO-L2S-001
- Arithmetic (1 pattern): BVD-CAIRO-ARI-001
- Reentrancy (4 patterns): BVD-CAIRO-REE-001 through BVD-CAIRO-REE-004
- State Variables (1 pattern): BVD-CAIRO-STA-001
- Code Quality (4 patterns): BVD-CAIRO-QUA-001 through BVD-CAIRO-QUA-004
- Memory Safety (1 pattern): BVD-CAIRO-MEM-001

**Category Codes**:
- REE (Reentrancy), ACC (Access Control), INT (Integer Issues)
- EXT (External Calls), STA (State Variables), TIM (Timing Issues)
- GAS (Gas Optimization), LOG (Logging/Events), DAT (Data Handling)
- L2S (Layer 2 Security), QUA (Code Quality), MEM (Memory Safety)
- PDA (Program Derived Addresses - Solana)
- And 30+ additional category codes

---

### `pattern_tool_mappings`

Mappings between scanner detector IDs and vulnerability patterns (Phase 4D).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique mapping identifier |
| `pattern_id` | VARCHAR(20) | NOT NULL, FK → vulnerability_patterns.id ON DELETE CASCADE, INDEX | Associated pattern |
| `scanner_id` | VARCHAR(50) | NOT NULL, INDEX | Scanner name (e.g., "slither", "mythril") |
| `detector_id` | VARCHAR(200) | NOT NULL, INDEX | Scanner-specific detector ID (e.g., "reentrancy-eth") |
| `confidence_threshold` | DOUBLE PRECISION | NULLABLE | Minimum confidence for match |
| `match_type` | VARCHAR(20) | NOT NULL, DEFAULT 'exact' | Match type (exact, fuzzy, ml) |
| `keywords_override` | TEXT[] | NULLABLE | Override keywords for this mapping |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true, INDEX | Active status flag |

**Indexes:**
- `pattern_tool_mappings_pkey` (PRIMARY KEY) on `id`
- `ix_pattern_tool_mappings_pattern_id` on `pattern_id`
- `ix_pattern_tool_mappings_scanner_id` on `scanner_id`
- `ix_pattern_tool_mappings_detector_id` on `detector_id`
- `ix_pattern_tool_mappings_is_active` on `is_active`
- `uq_pattern_tool_scanner_detector` (UNIQUE) on `(scanner_id, detector_id)`

**Relationships:**
- Many-to-one with `vulnerability_patterns` (pattern_id, CASCADE DELETE)

**Seed Data:** **398 scanner-to-pattern mappings** (updated 2025-11-02, Phase 6.7 migration complete) across 12 scanners - all pointing to BVD patterns

**Scanner Coverage (100% Intelligence Coverage + 100% BVD Compliance)**:

| Scanner | Detector Count | Mappings | Status | Test Coverage |
|---------|----------------|----------|--------|---------------|
| Slither | 93 | 93/93 (100%) | ✅ Production | 100% |
| Aderyn | 67 | 67/67 (100%) | ✅ Production | 100% |
| Semgrep | 54 | 54/54 (100%) | ✅ Production | 100% |
| Wake | 38 | 38/38 (100%) | ✅ Production | 95% |
| 4naly3er | 32 | 32/32 (100%) | ✅ Production | 95% |
| Solhint | 29 | 29/29 (100%) | ✅ Production | 90% |
| Mythril | 24 | 24/24 (100%) | ✅ Production | 90% |
| MythX | 22 | 22/22 (100%) | ✅ Production | 90% |
| **Caracal** | 14 | 14/14 (100%) | ✅ Production | 100% (Cairo) |
| Halmos | 12 | 12/12 (100%) | ✅ Production | 85% |
| Medusa | 8 | 8/8 (100%) | ✅ Production | 85% |
| Echidna | 4 | 4/4 (100%) | ✅ Production | 85% |
| **TOTAL** | **397** | **397/397 (100%)** | ✅ **100% Coverage** | **96% avg** |

**Validation Metrics (Phase 1-4 Complete - Nov 1, 2025)**:
- ✅ Pattern matching accuracy: 100% (397/397 detectors mapped)
- ✅ Coverage: 100% (all 12 scanners fully mapped)
- ✅ Performance: ~0.15ms per finding (average pattern matching)
- ✅ Tests passing: 428/428 unit tests + 31/31 integration tests

---

### `deduplication_groups`

**ADDED:** Migration 006 (2025-11-01) - Phase 3 Intelligence Validation
**UPDATED:** Migration 012 (2025-11-02) - Column rename fixes for Phase 6.6 hotfix

Groups of duplicate vulnerability findings detected by multiple scanners analyzing the same code location.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique group identifier |
| `canonical_finding_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE | Primary/canonical finding reference (renamed from `primary_vulnerability_id` in migration 012) |
| `contract_id` | UUID | NOT NULL, FK → contracts.id ON DELETE CASCADE | Associated contract |
| `pattern_code` | VARCHAR(50) | NULLABLE, FK → vulnerability_patterns.id ON DELETE SET NULL | Pattern code (e.g., "BVD-EVM-REE-001") (renamed from `pattern_id` in migration 012) |
| `group_size` | INTEGER | NOT NULL, DEFAULT 1 | Total number of vulnerabilities in this group |
| `strategy` | VARCHAR(20) | NOT NULL | Deduplication strategy (exact, fuzzy, semantic) |
| `confidence` | DOUBLE PRECISION | NOT NULL | Match confidence score (0.0 to 1.0) |
| `fingerprint_code` | VARCHAR(64) | NULLABLE | SHA-256 hash of normalized code snippet |
| `fingerprint_ast` | VARCHAR(64) | NULLABLE | SHA-256 hash of AST structure |
| `fingerprint_semantic` | VARCHAR(64) | NULLABLE | Semantic similarity fingerprint |
| `severity_distribution` | JSONB | NULLABLE | Distribution of severities in group (e.g., {"critical": 2, "high": 3}) |
| `scanner_distribution` | JSONB | NULLABLE | Distribution of scanners in group (e.g., {"slither": 3, "mythril": 2}) |
| `first_detected` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | First time this vulnerability was detected |
| `last_updated` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last time group was updated |
| `verified` | BOOLEAN | NOT NULL, DEFAULT false | Manual review completed flag |
| `verified_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | User who verified the group |
| `verified_at` | TIMESTAMPTZ | NULLABLE | Timestamp of verification |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Group creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Computed Properties (API-only, not database columns):**

The `DeduplicationGroupModel` SQLAlchemy model provides computed properties for API compatibility without requiring additional database columns:

| Property | Returns | Description |
|----------|---------|-------------|
| `scanner_count` | int | Number of unique scanners (computed from `scanner_distribution` JSONB keys) |
| `finding_count` | int | Alias for `group_size` field |
| `first_seen` | datetime | Alias for `first_detected` field |
| `last_seen` | datetime | Alias for `last_updated` field |
| `confidence_level` | str | Alias for `strategy` field (exact/fuzzy/semantic) |

**Implementation Note (Phase 6.6):** Computed properties use Python `@property` decorators rather than stored columns to avoid data duplication and maintain accuracy. This means `scanner_count` filtering must be done post-query in Python, not in SQL WHERE clauses. For production scale with large datasets, consider adding a PostgreSQL generated column or trigger for `scanner_count` to enable SQL-level filtering.

**Indexes:**
- `deduplication_groups_pkey` (PRIMARY KEY) on `id`
- `ix_dedup_fingerprint_code` on `fingerprint_code`
- `ix_dedup_canonical_finding` on `canonical_finding_id`
- Index on `pattern_code` (foreign key)
- Index on `contract_id` (foreign key)

**Relationships:**
- One-to-many with `vulnerabilities` (vulnerabilities reference deduplication_group_id)
- Many-to-one with `vulnerabilities` (canonical_finding_id references a single vulnerability as the "primary")

**Confidence Levels:**
- `exact`: Identical code_hash AND location_hash (99%+ precision)
- `high`: Identical code_hash OR location_hash (95%+ precision)
- `medium`: Identical ast_hash + same pattern (85%+ precision)
- `low`: Same pattern only (70%+ precision)

**Match Strategies:**
- `code_hash`: Exact code match after normalization
- `location_hash`: Same file, line, function
- `ast_hash`: Same AST structure (semantic match)
- `pattern`: Same vulnerability pattern only

**Deduplication Stats (Phase 3 Validation - Nov 1, 2025)**:
- ✅ Cross-scanner accuracy: >95%
- ✅ Collision rate: 0% (< 1% target exceeded)
- ✅ Code hash uniqueness: 100%
- ✅ Location hash uniqueness: 100%
- ✅ Canonical selection working correctly

**Example:**
```
Group ID: abc-123-def
Pattern: BVD-EVM-REE-001 (Reentrancy)
Fingerprint Code: a3f5e2c8... (SHA-256 of normalized code)
Finding Count: 3
Scanner Count: 3
Scanners: [slither, aderyn, semgrep]
Canonical Finding: vuln-456 (Slither finding chosen as primary)
Confidence: exact (all 3 scanners detected identical code at identical location)
```

---

### `organizations`

Multi-tenant organization support for enterprise features (Phase 4.5).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique organization identifier |
| `name` | VARCHAR(255) | NOT NULL | Organization display name |
| `slug` | VARCHAR(100) | NOT NULL, UNIQUE, INDEX | URL-friendly identifier |
| `description` | TEXT | NULLABLE | Organization description |
| `logo_url` | VARCHAR(2048) | NULLABLE | Logo URL |
| `tier` | VARCHAR(50) | NOT NULL, DEFAULT 'free' | Organization tier (free, pro, enterprise) |
| `stripe_customer_id` | VARCHAR(255) | NULLABLE, UNIQUE | Stripe customer ID for billing |
| `stripe_subscription_id` | VARCHAR(255) | NULLABLE | Stripe subscription ID |
| `sso_enabled` | BOOLEAN | NOT NULL, DEFAULT false | SSO enabled flag |
| `sso_provider` | VARCHAR(50) | NULLABLE | SSO provider (saml, oidc) |
| `sso_config` | JSONB | NULLABLE | SSO configuration JSON |
| `sso_domain` | VARCHAR(255) | NULLABLE, INDEX | Domain for SSO authentication |
| `settings` | JSONB | NULLABLE, DEFAULT '{}' | Organization settings |
| `owner_id` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | Organization owner |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true | Active status |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_organizations_slug` (UNIQUE) on `slug`
- `ix_organizations_sso_domain` on `sso_domain`
- `ix_organizations_owner_id` on `owner_id`

**Relationships:**
- One-to-many with `organization_members`
- One-to-many with `roles`
- One-to-many with `webhooks`
- One-to-many with `api_keys`
- One-to-many with `audit_logs`

---

### `roles`

RBAC role definitions for organization access control (Phase 4.5).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique role identifier |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE CASCADE | Associated organization (NULL for system roles) |
| `name` | VARCHAR(100) | NOT NULL | Role name (e.g., 'admin', 'member') |
| `display_name` | VARCHAR(255) | NOT NULL | Human-readable name |
| `description` | TEXT | NULLABLE | Role description |
| `permissions` | JSONB | NOT NULL, DEFAULT '[]' | Permission array (e.g., ['scan:read', 'scan:write']) |
| `is_system_role` | BOOLEAN | NOT NULL, DEFAULT false | System roles cannot be modified |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_roles_organization_id` on `organization_id`
- `uq_roles_org_name` (UNIQUE) on `(organization_id, name)`

**Relationships:**
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)
- One-to-many with `organization_members`

**System Roles (seeded):**
- `owner` - Full access, can manage organization
- `admin` - Full access except billing/deletion
- `member` - Read access, limited write
- `viewer` - Read-only access

---

### `organization_members`

Organization membership with role assignment (Phase 4.5).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique membership identifier |
| `organization_id` | UUID | NOT NULL, FK → organizations.id ON DELETE CASCADE | Organization reference |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | User reference |
| `role_id` | UUID | NOT NULL, FK → roles.id ON DELETE RESTRICT | Assigned role |
| `invited_by` | UUID | NULLABLE | User who sent the invitation |
| `invited_at` | TIMESTAMPTZ | NULLABLE | Invitation timestamp |
| `joined_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Join timestamp |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true | Active membership status |

**Indexes:**
- `ix_org_members_organization_id` on `organization_id`
- `ix_org_members_user_id` on `user_id`
- `ix_org_members_role_id` on `role_id`
- `uq_org_members_org_user` (UNIQUE) on `(organization_id, user_id)`

**Relationships:**
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `roles` (role_id, RESTRICT DELETE)

---

### `webhooks`

Webhook configuration for event notifications (Phase 4.5).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique webhook identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | Owner user |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE CASCADE | Associated organization |
| `name` | VARCHAR(255) | NOT NULL | Webhook name |
| `url` | VARCHAR(2048) | NOT NULL | Delivery endpoint URL |
| `secret` | VARCHAR(255) | NOT NULL | HMAC-SHA256 signing secret |
| `events` | JSONB | NOT NULL | Array of event types to subscribe |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true | Active status |
| `retry_count` | INTEGER | NOT NULL, DEFAULT 3 | Max delivery retries |
| `timeout_seconds` | INTEGER | NOT NULL, DEFAULT 30 | Request timeout |
| `total_deliveries` | INTEGER | NOT NULL, DEFAULT 0 | Total delivery attempts |
| `successful_deliveries` | INTEGER | NOT NULL, DEFAULT 0 | Successful deliveries |
| `failed_deliveries` | INTEGER | NOT NULL, DEFAULT 0 | Failed deliveries |
| `last_triggered_at` | TIMESTAMPTZ | NULLABLE | Last trigger timestamp |
| `last_success_at` | TIMESTAMPTZ | NULLABLE | Last successful delivery |
| `last_failure_at` | TIMESTAMPTZ | NULLABLE | Last failed delivery |
| `last_error` | TEXT | NULLABLE | Last error message |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_webhooks_user_id` on `user_id`
- `ix_webhooks_organization_id` on `organization_id`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)
- One-to-many with `webhook_deliveries`

**Event Types:**
- `scan.started` - Scan has begun processing
- `scan.completed` - Scan finished successfully
- `scan.failed` - Scan encountered an error
- `vulnerability.detected` - New vulnerability found
- `vulnerability.resolved` - Vulnerability marked as resolved

---

### `webhook_deliveries`

Webhook delivery history and retry tracking (Phase 4.5).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique delivery identifier |
| `webhook_id` | UUID | NOT NULL, FK → webhooks.id ON DELETE CASCADE | Parent webhook |
| `event_type` | VARCHAR(50) | NOT NULL, INDEX | Event type delivered |
| `event_id` | VARCHAR(100) | NOT NULL, INDEX | Unique event identifier |
| `payload` | JSONB | NOT NULL | Request payload |
| `headers` | JSONB | NULLABLE | Request headers |
| `status_code` | INTEGER | NULLABLE | Response status code |
| `response_body` | TEXT | NULLABLE | Response body |
| `response_headers` | JSONB | NULLABLE | Response headers |
| `attempt_number` | INTEGER | NOT NULL, DEFAULT 1 | Delivery attempt number |
| `success` | BOOLEAN | NOT NULL, DEFAULT false | Delivery success status |
| `error_message` | TEXT | NULLABLE | Error message if failed |
| `duration_ms` | INTEGER | NULLABLE | Request duration in milliseconds |
| `triggered_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Trigger timestamp |
| `delivered_at` | TIMESTAMPTZ | NULLABLE | Successful delivery timestamp |

**Indexes:**
- `ix_webhook_deliveries_webhook_id` on `webhook_id`
- `ix_webhook_deliveries_event_type` on `event_type`
- `ix_webhook_deliveries_event_id` on `event_id`
- `ix_webhook_deliveries_triggered_at` on `triggered_at`

**Relationships:**
- Many-to-one with `webhooks` (webhook_id, CASCADE DELETE)

---

### `api_keys`

API keys for programmatic access (Phase 4.5).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique API key identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | Owner user |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE CASCADE | Associated organization |
| `name` | VARCHAR(255) | NOT NULL | Key name/description |
| `key_prefix` | VARCHAR(10) | NOT NULL, INDEX | First 8 chars for identification |
| `key_hash` | VARCHAR(255) | NOT NULL | SHA-256 hash of full key |
| `scopes` | JSONB | NOT NULL, DEFAULT '[]' | Permission scopes |
| `rate_limit_per_minute` | INTEGER | NOT NULL, DEFAULT 60 | Requests per minute limit |
| `rate_limit_per_hour` | INTEGER | NOT NULL, DEFAULT 1000 | Requests per hour limit |
| `last_used_at` | TIMESTAMPTZ | NULLABLE | Last usage timestamp |
| `total_requests` | INTEGER | NOT NULL, DEFAULT 0 | Total API requests made |
| `expires_at` | TIMESTAMPTZ | NULLABLE | Key expiration timestamp |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true | Active status |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `revoked_at` | TIMESTAMPTZ | NULLABLE | Revocation timestamp |

**Indexes:**
- `ix_api_keys_user_id` on `user_id`
- `ix_api_keys_organization_id` on `organization_id`
- `ix_api_keys_key_prefix` on `key_prefix`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)

**API Key Scopes:**
- `scan:read` - Read scan results
- `scan:write` - Create scans
- `contract:read` - Read contracts
- `contract:write` - Upload contracts
- `vulnerability:read` - Read vulnerabilities
- `webhook:manage` - Manage webhooks

---

### `audit_logs`

Comprehensive audit trail for security and compliance (Phase 4.5).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique log entry identifier |
| `user_id` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | Acting user (NULL for system) |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE SET NULL | Organization context |
| `action` | VARCHAR(100) | NOT NULL, INDEX | Action name (e.g., 'user.login', 'scan.create') |
| `resource_type` | VARCHAR(50) | NULLABLE, INDEX | Resource type affected |
| `resource_id` | UUID | NULLABLE, INDEX | Resource identifier |
| `ip_address` | VARCHAR(45) | NULLABLE | Client IP address (IPv6 max) |
| `user_agent` | VARCHAR(500) | NULLABLE | Client user agent |
| `request_id` | VARCHAR(100) | NULLABLE, INDEX | Request correlation ID |
| `old_values` | JSONB | NULLABLE | Previous values (for updates) |
| `new_values` | JSONB | NULLABLE | New values (for creates/updates) |
| `event_metadata` | JSONB | NULLABLE | Additional event metadata |
| `success` | BOOLEAN | NOT NULL, DEFAULT true | Action success status |
| `error_message` | TEXT | NULLABLE | Error message if failed |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Log entry timestamp |

**Indexes:**
- `ix_audit_logs_user_id` on `user_id`
- `ix_audit_logs_organization_id` on `organization_id`
- `ix_audit_logs_action` on `action`
- `ix_audit_logs_resource_type` on `resource_type`
- `ix_audit_logs_resource_id` on `resource_id`
- `ix_audit_logs_request_id` on `request_id`
- `ix_audit_logs_created_at` on `created_at`

**Relationships:**
- Many-to-one with `users` (user_id, SET NULL on DELETE)
- Many-to-one with `organizations` (organization_id, SET NULL on DELETE)

**Audit Actions:**
- `user.login`, `user.logout`, `user.create`, `user.update`
- `scan.create`, `scan.complete`, `scan.fail`
- `contract.upload`, `contract.delete`
- `webhook.create`, `webhook.delete`, `webhook.trigger`
- `api_key.create`, `api_key.revoke`
- `organization.create`, `organization.update`, `organization.delete`
- `member.invite`, `member.join`, `member.remove`

---

### `credit_packages`

Credit packages available for purchase (Phase 3.4 - x402 Pay-Per-Scan).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique package identifier |
| `name` | VARCHAR(50) | NOT NULL | Package name (e.g., 'Starter', 'Pro', 'Enterprise') |
| `credits` | INTEGER | NOT NULL | Number of scan credits included |
| `price_usd` | NUMERIC(10,2) | NOT NULL | Price in USD |
| `discount_percent` | INTEGER | NOT NULL, DEFAULT 0 | Discount percentage (0-100) |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true | Available for purchase |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |

**Indexes:**
- `ix_credit_packages_is_active` on `is_active`

**Relationships:**
- One-to-many with `payment_transactions`

**Seed Data:**
| Name | Credits | Price USD | Discount |
|------|---------|-----------|----------|
| Starter | 10 | $8.00 | 20% |
| Pro | 50 | $35.00 | 30% |
| Enterprise | 200 | $120.00 | 40% |

---

### `scan_credits`

User's scan credit balance (Phase 3.4 - x402 Pay-Per-Scan).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique credit record identifier |
| `user_id` | UUID | NOT NULL, UNIQUE, FK → users.id ON DELETE CASCADE | User reference |
| `balance` | INTEGER | NOT NULL, DEFAULT 0 | Current credit balance |
| `total_purchased` | INTEGER | NOT NULL, DEFAULT 0 | Total credits ever purchased |
| `total_used` | INTEGER | NOT NULL, DEFAULT 0 | Total credits ever used |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_scan_credits_user_id` (UNIQUE) on `user_id`

**Relationships:**
- One-to-one with `users` (user_id, CASCADE DELETE)
- One-to-many with `credit_transactions`

---

### `payment_transactions`

x402 payment transactions for credits and per-scan payments (Phase 3.4).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique transaction identifier |
| `user_id` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | Paying user |
| `payment_type` | VARCHAR(20) | NOT NULL | Payment type ('per_scan', 'credits') |
| `amount_usd` | NUMERIC(10,4) | NOT NULL | Amount in USD |
| `token` | VARCHAR(10) | NOT NULL, DEFAULT 'USDC' | Payment token (USDC) |
| `network` | VARCHAR(20) | NOT NULL, DEFAULT 'base' | Blockchain network |
| `tx_hash` | VARCHAR(66) | NULLABLE, INDEX | Blockchain transaction hash |
| `from_address` | VARCHAR(42) | NULLABLE | Sender wallet address |
| `to_address` | VARCHAR(42) | NULLABLE | Recipient wallet address |
| `block_number` | INTEGER | NULLABLE | Blockchain block number |
| `x402_payment_id` | VARCHAR(255) | NULLABLE | x402 protocol payment ID |
| `facilitator_response` | JSONB | NULLABLE | x402 facilitator response |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'pending', INDEX | Status (pending, verified, failed, refunded) |
| `verified_at` | TIMESTAMPTZ | NULLABLE | Verification timestamp |
| `credits_purchased` | INTEGER | NULLABLE | Credits purchased (for credit purchases) |
| `package_id` | UUID | NULLABLE, FK → credit_packages.id ON DELETE SET NULL | Credit package purchased |
| `scan_id` | UUID | NULLABLE, FK → scans.id ON DELETE SET NULL | Associated scan (for per-scan) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_payment_transactions_user_id` on `user_id`
- `ix_payment_transactions_tx_hash` on `tx_hash`
- `ix_payment_transactions_status` on `status`
- `ix_payment_transactions_created_at` on `created_at`

**Relationships:**
- Many-to-one with `users` (user_id, SET NULL on DELETE)
- Many-to-one with `credit_packages` (package_id, SET NULL on DELETE)
- One-to-one with `scans` (scan_id, SET NULL on DELETE)
- One-to-many with `credit_transactions`

---

### `credit_transactions`

Credit usage and purchase history (Phase 3.4 - x402 Pay-Per-Scan).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique transaction identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | User reference |
| `credits` | INTEGER | NOT NULL | Credit change (positive=purchase, negative=usage) |
| `balance_after` | INTEGER | NOT NULL | Balance after transaction |
| `transaction_type` | VARCHAR(20) | NOT NULL, INDEX | Type (purchase, scan_usage, refund, gift) |
| `payment_transaction_id` | UUID | NULLABLE, FK → payment_transactions.id ON DELETE SET NULL | Associated payment |
| `scan_id` | UUID | NULLABLE, FK → scans.id ON DELETE SET NULL | Associated scan |
| `description` | VARCHAR(255) | NULLABLE | Transaction description |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Transaction timestamp |

**Indexes:**
- `ix_credit_transactions_user_id` on `user_id`
- `ix_credit_transactions_transaction_type` on `transaction_type`
- `ix_credit_transactions_created_at` on `created_at`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `payment_transactions` (payment_transaction_id, SET NULL on DELETE)
- Many-to-one with `scans` (scan_id, SET NULL on DELETE)

**Transaction Types:**
- `purchase` - Credits purchased via x402 payment
- `scan_usage` - Credits used for a scan
- `refund` - Credits refunded (e.g., failed scan)
- `gift` - Credits granted by admin

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

### `sbom_format`

**PLANNED** (Phase 3.1) - SBOM format specification.

**⚠️ STATUS: FULLY REVERTED (November 30, 2025)**

SBOM feature was completely rolled back:
1. **API Endpoints**: Reverted via `git revert` (commit efd2b6f)
2. **Database Tables**: Removed via `alembic downgrade 20251128_1600`
3. **Migration File**: `20251129_1000-add_sbom_tables.py` removed
4. **Historical Data**: 7 SBOM scans and 3 related vulnerabilities deleted

The `sboms` and `sbom_components` tables no longer exist. SBOM functionality will be reimplemented in a future sprint with:
- Proper testing against authentication flow
- Isolated deployment to prevent auth conflicts
- Full integration with SolidityBOM scanner

**Values (for future reference):**
- `spdx_2_3` - SPDX version 2.3
- `cyclonedx_1_5` - CycloneDX version 1.5

**Usage:** N/A - tables removed

---

### `sbom_output_format`

**PLANNED** (Phase 3.1) - SBOM output format.

**Values:**
- `json` - JSON format
- `xml` - XML format
- `yaml` - YAML format
- `rdf` - RDF/XML format (SPDX only)

**Usage:** `sboms.output_format`

---

### `component_type`

**PLANNED** (Phase 3.1) - Component type classification.

**Values:**
- `library` - Software library/package
- `application` - Standalone application
- `framework` - Development framework
- `operating-system` - Operating system component
- `device` - Hardware device
- `firmware` - Firmware component
- `file` - Individual file
- `container` - Container image
- `platform` - Platform/runtime environment
- `other` - Other component type

**Usage:** `sbom_components.type`

---

### `relationship_type`

**PLANNED** (Phase 3.1) - SBOM component relationship types.

**Values:**
- `depends_on` - Dependency relationship
- `contains` - Contains/includes relationship
- `described_by` - Described by documentation
- `generates` - Generates artifact
- `ancestor_of` - Ancestor in dependency tree
- `descendant_of` - Descendant in dependency tree
- `variant_of` - Variant of component
- `build_tool_of` - Build tool relationship
- `dev_tool_of` - Development tool relationship
- `test_tool_of` - Testing tool relationship
- `runtime_dependency_of` - Runtime dependency
- `dev_dependency_of` - Development dependency
- `optional_dependency_of` - Optional dependency
- `provided_dependency_of` - Provided dependency
- `test_dependency_of` - Test dependency

**Usage:** `sbom_relationships.relationship_type`

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

**Document Version:** 1.6.0
**Last Updated:** December 7, 2025 (Added 7 missing scanner result tables, 32 total tables)
**Maintained By:** BlockSecOps Team

---

## Phase 4D Summary

**Phase 4D: Intelligence Layer - Enrichment and Fingerprinting** was completed on October 25, 2025.

### Key Changes

1. **Parser Enrichment Fields** (Migration 005)
   - Added `detector_id`, `file_path`, `function_name`, `contract_name` to vulnerabilities table
   - Parsers now extract these fields automatically from scanner output
   - Enables location-based fingerprinting and context-aware enrichment

2. **Gas Analysis Enrichment** (Migration 006)
   - Added same enrichment fields to gas_analysis_findings table
   - Ensures consistent enrichment across all finding types

3. **Vulnerability Patterns System**
   - 30 standard vulnerability patterns seeded (vulnerability_patterns table)
   - 21 scanner-to-pattern mappings seeded (pattern_tool_mappings table)
   - Enables automatic classification of findings to standard patterns

4. **Fingerprinting System**
   - Code fingerprinting (SHA-256 hash of normalized code)
   - AST fingerprinting (SHA-256 hash of abstract syntax tree)
   - Location fingerprinting (exact and fuzzy line range hashing)
   - Semantic fingerprinting (for similarity matching)
   - Composite fingerprinting (combined hash for deduplication)

5. **SQLAlchemy Model Alignment**
   - Fixed VulnerabilityModel to include all 15 Phase 4D fields
   - Resolved "invalid keyword argument" errors in orchestration service
   - Enabled successful storage of enriched findings

### Related Documentation

- **Implementation Summary**: `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/implementation-summaries/PHASE-4D-IMPLEMENTATION-COMPLETE.md`
- **Model Fixes**: `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/03-phase-4-intelligence/PHASE-4D-MODEL-FIXES-COMPLETE.md`
- **Parser Fixes**: `/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/03-phase-4-intelligence/PHASE-4D-PARSER-CLASSIFICATION-FIX-COMPLETE.md`
- **Migration Files**: `/Users/pwner/Git/ABS/database/migrations/`

### Next Phase

**Phase 4E: Deduplication Engine** will build on the fingerprinting system to:
- Identify duplicate findings across scanners
- Group related findings into deduplication groups
- Select canonical findings from duplicate groups
- Provide deduplication API and UI
