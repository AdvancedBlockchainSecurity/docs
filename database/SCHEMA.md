# BlockSecOps Database Schema

**Version:** 3.1a.1 (Phase 3.1a File Upload Restrictions + Quota Enforcement Complete)
**Database:** PostgreSQL 15.4
**Last Updated:** November 15, 2025
**Migration Version:** 005 (manual) - Intelligence tables + missing vulnerability columns
**Orchestration Version:** 0.7.17 - SQLAlchemy model fixes for Phase 4D
**Pattern Code Format:** BVD-[ECOSYSTEM]-[CATEGORY]-[NUMBER] (Multi-Ecosystem Taxonomy - 100% Compliance)
**Pattern Database Version:** 3.9+ - 🚀 Phase 3.1 Planned (352 → 392-432 patterns, 12 → 13 scanners)
**Intelligence Layer Status:** ✅ Phase 1-4 Tables Created | 🟢 Phase 3.1 SBOM Tables Planned
**Scanner Count:** 26 → **27** (adding SolidityDefend)
**Tool Count:** 27 → **28** (adding SolidityBOM)
**Detector Count:** 393 → **597** (adding 204 from SolidityDefend)

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
- **User authentication:** ✅ **Supabase Auth** with ES256 JWT tokens and JWKS verification (migrated November 13, 2025)
- **Security scanning:** Vulnerability detection with severity classification and multi-scanner support
- **Scanner tracking:** Attribution and categorization of vulnerabilities by detection tool (Migration 004)
- **Saved searches:** User-saved search queries with JSONB parameters (Migration 004)
- **User preferences:** Customizable notification settings and UI preferences (Migration 004)
- **Performance optimization:** 13+ specialized indexes including GIN, composite, and partial indexes (Migration 004)
- **Audit tracking:** Full timestamps and status tracking
- **Intelligence layer:** Phase 4D enrichment and fingerprinting for vulnerability deduplication (Migrations 005-006)
- **Pattern matching:** Vulnerability pattern classification with **352 patterns across 4 ecosystems** (Pattern DB v3.9, 2025-11-02) → **Phase 3.1: 392-432 patterns** (adding 40-80 for SolidityDefend)
  - **Solidity/EVM**: 171 patterns → **211-251 patterns** (adding 40-80 from SolidityDefend)
  - **Vyper**: 99 patterns
  - **Solana**: 68 patterns
  - **Cairo/Starknet**: 14 patterns
- **SBOM Support (Phase 3.1):** Software Bill of Materials tables for dependency tracking
  - **SBOM Formats**: SPDX 2.3, CycloneDX 1.5
  - **Dependency Scanning**: CVE detection, license compliance
  - **Supply Chain Security**: Malicious package detection
- **100% BVD Standard Compliance:** All 352 patterns use BVD-{ECOSYSTEM}-{CATEGORY}-{NUMBER} format 🎯 (Phase 6.7 Migration Complete)
- **100% Intelligence Coverage:** All 398 detector mappings across 12 scanners point to BVD patterns (Phase 1-4 + 6.7 Complete)
- **Deduplication:** Cross-scanner finding deduplication with 0% collision rate (Phase 3 Validation)
- **Ecosystem-based taxonomy:** Multi-ecosystem support with explicit ecosystem identifiers (SOLIDITY, VYPER, SOLANA, **CAIRO**) (Migration 008, v3.8)
- **Parser enrichment:** Automatic extraction of detector_id, file_path, function_name, contract_name from scanner output (Phase 4D)

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

**Indexes:**
- `ix_users_email` (UNIQUE) on `email`
- `ix_users_tier` on `tier`
- `ix_users_supabase_user_id` (UNIQUE) on `supabase_user_id`

**Relationships:**
- One-to-many with `sessions`
- One-to-many with `contracts`
- One-to-many with `scans`
- One-to-many with `projects`
- One-to-one with `user_quotas`

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

### `sboms`

**PLANNED** (Phase 3.1) - Software Bill of Materials records.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique SBOM identifier |
| `contract_id` | UUID | NOT NULL, FK → contracts.id ON DELETE CASCADE | Associated contract |
| `user_id` | UUID | NOT NULL, FK → users.id | SBOM owner |
| `format` | sbom_format | NOT NULL | SBOM format (spdx_2_3, cyclonedx_1_5) |
| `output_format` | sbom_output_format | NOT NULL | Output format (json, xml, yaml, rdf) |
| `spdx_version` | VARCHAR(20) | NULLABLE | SPDX version (e.g., "2.3") |
| `cyclonedx_version` | VARCHAR(20) | NULLABLE | CycloneDX version (e.g., "1.5") |
| `document_namespace` | TEXT | NULLABLE | SBOM document namespace URI |
| `creator` | TEXT | NOT NULL | SBOM creator information |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | SBOM generation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |
| `component_count` | INTEGER | NOT NULL, DEFAULT 0 | Total number of components |
| `vulnerability_count` | INTEGER | NOT NULL, DEFAULT 0 | Total vulnerabilities found |
| `license_count` | INTEGER | NOT NULL, DEFAULT 0 | Number of unique licenses |
| `sbom_data` | JSONB | NOT NULL | Full SBOM document (SPDX/CycloneDX JSON) |

**Indexes:**
- `ix_sboms_contract_id` on `contract_id`
- `ix_sboms_user_id` on `user_id`
- `ix_sboms_format` on `format`
- `ix_sboms_created_at` on `created_at DESC`

**Relationships:**
- Many-to-one with `contracts` (contract_id, CASCADE DELETE)
- Many-to-one with `users` (user_id)
- One-to-many with `sbom_components`
- One-to-many with `sbom_vulnerabilities`

---

### `sbom_components`

**PLANNED** (Phase 3.1) - Individual components/dependencies in SBOM.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique component identifier |
| `sbom_id` | UUID | NOT NULL, FK → sboms.id ON DELETE CASCADE | Parent SBOM |
| `spdx_id` | VARCHAR(255) | NULLABLE | SPDX element identifier |
| `name` | VARCHAR(255) | NOT NULL | Component name |
| `version` | VARCHAR(100) | NULLABLE | Component version |
| `package_manager` | VARCHAR(50) | NULLABLE | Package manager (npm, pip, cargo, etc.) |
| `license` | VARCHAR(255) | NULLABLE | License identifier |
| `supplier` | TEXT | NULLABLE | Component supplier/vendor |
| `download_location` | TEXT | NULLABLE | Package download URL |
| `homepage` | TEXT | NULLABLE | Component homepage URL |
| `purl` | TEXT | NULLABLE | Package URL (purl) |
| `cpe` | TEXT | NULLABLE | Common Platform Enumeration |
| `type` | component_type | NOT NULL | Component type (library, application, framework, etc.) |
| `is_direct_dependency` | BOOLEAN | NOT NULL, DEFAULT false | Direct vs transitive dependency |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Discovery timestamp |

**Indexes:**
- `ix_sbom_components_sbom_id` on `sbom_id`
- `ix_sbom_components_name` on `name`
- `ix_sbom_components_package_manager` on `package_manager`
- `ix_sbom_components_purl` on `purl` (for CVE lookups)

**Relationships:**
- Many-to-one with `sboms` (sbom_id, CASCADE DELETE)
- One-to-many with `sbom_vulnerabilities`

---

### `sbom_vulnerabilities`

**PLANNED** (Phase 3.1) - Vulnerabilities found in SBOM components.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique vulnerability identifier |
| `sbom_id` | UUID | NOT NULL, FK → sboms.id ON DELETE CASCADE | Associated SBOM |
| `component_id` | UUID | NOT NULL, FK → sbom_components.id ON DELETE CASCADE | Affected component |
| `cve_id` | VARCHAR(50) | NULLABLE, INDEX | CVE identifier (e.g., CVE-2023-12345) |
| `ghsa_id` | VARCHAR(50) | NULLABLE, INDEX | GitHub Advisory identifier |
| `title` | VARCHAR(255) | NOT NULL | Vulnerability title |
| `description` | TEXT | NOT NULL | Vulnerability description |
| `severity` | vulnerability_severity | NOT NULL | Severity level |
| `cvss_score` | NUMERIC(3,1) | NULLABLE | CVSS score (0.0-10.0) |
| `cvss_vector` | VARCHAR(100) | NULLABLE | CVSS vector string |
| `affected_versions` | TEXT[] | NULLABLE | Affected version ranges |
| `fixed_versions` | TEXT[] | NULLABLE | Versions with fix |
| `references` | JSONB | NULLABLE | Reference URLs (advisories, patches) |
| `published_at` | TIMESTAMPTZ | NULLABLE | Vulnerability publication date |
| `discovered_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | When we discovered it |

**Indexes:**
- `ix_sbom_vulnerabilities_sbom_id` on `sbom_id`
- `ix_sbom_vulnerabilities_component_id` on `component_id`
- `ix_sbom_vulnerabilities_cve_id` on `cve_id`
- `ix_sbom_vulnerabilities_ghsa_id` on `ghsa_id`
- `ix_sbom_vulnerabilities_severity` on `severity`

**Relationships:**
- Many-to-one with `sboms` (sbom_id, CASCADE DELETE)
- Many-to-one with `sbom_components` (component_id, CASCADE DELETE)

---

### `sbom_relationships`

**PLANNED** (Phase 3.1) - Relationships between SBOM components.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique relationship identifier |
| `sbom_id` | UUID | NOT NULL, FK → sboms.id ON DELETE CASCADE | Associated SBOM |
| `source_component_id` | UUID | NOT NULL, FK → sbom_components.id ON DELETE CASCADE | Source component |
| `target_component_id` | UUID | NOT NULL, FK → sbom_components.id ON DELETE CASCADE | Target component |
| `relationship_type` | relationship_type | NOT NULL | Relationship type (depends_on, contains, etc.) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Relationship discovery timestamp |

**Indexes:**
- `ix_sbom_relationships_sbom_id` on `sbom_id`
- `ix_sbom_relationships_source_component` on `source_component_id`
- `ix_sbom_relationships_target_component` on `target_component_id`

**Relationships:**
- Many-to-one with `sboms` (sbom_id, CASCADE DELETE)
- Many-to-one with `sbom_components` (source_component_id, CASCADE DELETE)
- Many-to-one with `sbom_components` (target_component_id, CASCADE DELETE)

---

### `sbom_licenses`

**PLANNED** (Phase 3.1) - License information from SBOM.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique license identifier |
| `sbom_id` | UUID | NOT NULL, FK → sboms.id ON DELETE CASCADE | Associated SBOM |
| `component_id` | UUID | NULLABLE, FK → sbom_components.id ON DELETE CASCADE | Associated component (nullable for SBOM-level licenses) |
| `license_id` | VARCHAR(255) | NOT NULL | SPDX license identifier |
| `license_name` | VARCHAR(255) | NOT NULL | Human-readable license name |
| `license_text` | TEXT | NULLABLE | Full license text |
| `is_osi_approved` | BOOLEAN | NOT NULL, DEFAULT false | OSI approved license |
| `is_copyleft` | BOOLEAN | NOT NULL, DEFAULT false | Copyleft license |
| `license_url` | TEXT | NULLABLE | License reference URL |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Discovery timestamp |

**Indexes:**
- `ix_sbom_licenses_sbom_id` on `sbom_id`
- `ix_sbom_licenses_component_id` on `component_id`
- `ix_sbom_licenses_license_id` on `license_id`

**Relationships:**
- Many-to-one with `sboms` (sbom_id, CASCADE DELETE)
- Many-to-one with `sbom_components` (component_id, CASCADE DELETE, optional)

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

**Values:**
- `spdx_2_3` - SPDX version 2.3
- `cyclonedx_1_5` - CycloneDX version 1.5

**Usage:** `sboms.format`

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

## Migration History

| Version | Date | Description | File |
|---------|------|-------------|------|
| **001** | 2025-10-12 | Initial database schema with users, contracts, scans, vulnerabilities, multi-language and multi-file support | `20251012_1500-001_initial_schema.py` |
| **002** | 2025-10-14 | Add 'uploaded' status to contract_status enum | `20251014_1400-002_add_uploaded_status.py` |
| **003** | 2025-10-15 | Add projects table and project_contracts junction table for project organization | `20251015_1000-003_add_projects_table.py` |
| **004** | 2025-10-18 | Comprehensive production enhancements: scanner tracking, vulnerability categorization, saved searches, user preferences, enrichment fingerprints, and performance indexes | `20251017_2112-08bf8921767b_comprehensive_production_enhancements_.py` |
| **005** | 2025-10-24 | **Phase 4D Parser Enrichment** - Add parser enrichment fields to vulnerabilities table (detector_id, file_path, function_name, contract_name) for intelligence layer | `20251024_add_parser_enrichment_fields.sql` |
| **006** | 2025-10-24 | **Phase 4D Gas Analysis Enrichment** - Add parser enrichment fields to gas_analysis_findings table for consistent enrichment across finding types | `20251024_add_parser_fields_to_gas_analysis.sql` |
| **012** | 2025-11-02 | **Phase 6.6 Deduplication Groups Fix** - Rename columns in deduplication_groups table (`primary_vulnerability_id` → `canonical_finding_id`, `pattern_id` → `pattern_code` VARCHAR(50)) | `20251102_1251-a2240d8cd745_fix_deduplication_groups_column_names.py` |
| **013** | 2025-11-12 | **Phase 3.1a Supabase Auth Integration** - Add tier tracking columns to users table (tier, tier_updated_at, supabase_user_id, stripe_customer_id, stripe_subscription_id) | `20251112_1408-cf314965ed8c_add_supabase_tier_tracking_to_users.py` |
| **014** | 2025-11-12 | **Phase 3.1a User Quotas** - Create user_quotas table with auto-creation trigger for tier-based limits | `20251112_1453-efa3c7c50d04_create_user_quotas_table_with_trigger.py` |
| **N/A** | 2025-10-24 | **Code Fix** - Removed is_project field references from ORM model and task logic (orchestration v0.7.10-0.7.11) | Field planned for future migration |
| **N/A** | 2025-10-24 | **Intelligence Layer** - Implemented intelligence modules for Phase 4C/4D enrichment (orchestration v0.7.12-0.7.17) | intelligence/models.py, intelligence/normalizer.py, intelligence/fingerprinting.py |
| **N/A** | 2025-10-25 | **SQLAlchemy Model Fix** - Added 15 missing field definitions to VulnerabilityModel for Phase 4D fingerprinting (orchestration v0.7.17-fingerprint-model-fix) | src/blocksecops_orchestration/models/models.py |
| **N/A** | 2025-11-02 | **Phase 6.6 Deduplication API Fix** - Added computed properties to DeduplicationGroupModel (scanner_count, finding_count, first_seen, last_seen, confidence_level) for API compatibility (API service v0.1.12) | `src/infrastructure/database/specialized_models/intelligence.py` |

**Note:** After October 16, 2025 database recovery, migration 002 required manual application. See [MANUAL-FIXES.md](./MANUAL-FIXES.md) for details on any required manual fixes when recreating the database.

**is_project Field Status:** The `is_project` column was documented in the schema but never existed in the actual database. This created a schema mismatch that was resolved in orchestration service v0.7.10 and v0.7.11 by commenting out the ORM field definition and removing conditional logic. The field will be added in a future migration when full project structure support is implemented.

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

**Document Version:** 1.2.1
**Last Updated:** November 2, 2025 (Phase 6.6 hotfix)
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
