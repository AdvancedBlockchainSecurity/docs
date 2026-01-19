# BlockSecOps Database Schema

**Database:** PostgreSQL 15.4
**Database Name:** `solidity_security`
**Schema:** `public`
**Timezone:** UTC

> **Important Note on Database Naming:**
> The database is named `solidity_security`, NOT `blocksecops`. This name was established during initial platform development when the focus was solely on Solidity security scanning. The name has been retained for backward compatibility and to avoid migration complexity. All services, connection strings, and documentation should reference `solidity_security`.
>
> **Verified:** January 18, 2026 (SolidityDefend v1.10.3 verification confirmed 15 scanners, 58 contracts, 115 scans, 6,317 vulnerabilities in `solidity_security` database)

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

- **Multi-language support:** Solidity, Vyper, and Solana/Rust (16/16 scanners available as of December 15, 2025)
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
- **Pattern matching:** Vulnerability pattern classification across 3 ecosystems (Solidity/EVM, Vyper, Solana/Rust)
- **Deduplication:** Cross-scanner finding deduplication
- **Tier-based quotas:** User quotas with monthly scan limits and tier-based priority
- **Priority queue:** Scan priority system for tier-based queue processing
- **Wallet authentication:** MetaMask/WalletConnect SIWE authentication (Phase 3.3)
- **Enterprise features:** Organizations, RBAC, webhooks, API keys, audit logs (Phase 4.5)
- **x402 payments:** Pay-per-scan with USDC, scan credits, payment transactions (Phase 3.4)
- **Scanner results:** Specialized result tables for gas analysis, fuzzing, formal verification, code quality (Phase 3)
- **Contract analysis:** Parsed function, event, and state variable definitions from contracts
- **Activity logging:** User activity tracking for uploads, scans, payments, and credit usage (Phase 3.1b)
- **Favorites:** User favorites/pinned items for quick access (Phase 3.1b Sprint 3)
- **Vulnerability annotations:** Mark vulnerabilities with status and notes (Phase 3.1b Sprint 3)
- **Batch scans:** Multi-contract batch scan operations (Phase 3.1b Sprint 3)
- **Team collaboration:** Teams, project access control, assignments, comments (Phase 4.5)
- **Notification channels:** Slack, Teams, Discord webhook integrations (CI/CD Integrations - January 2026)
- **Quality gates:** CI/CD pipeline quality gate configurations and evaluation history (Phase 5.5c - January 2026)

**Total Tables:** 49 (excluding alembic_version)

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
| `tier` | VARCHAR(20) | NOT NULL, DEFAULT 'free', INDEX | User tier (free, developer, startup, professional, enterprise) |
| `tier_updated_at` | TIMESTAMPTZ | NULLABLE, DEFAULT now() | Last tier change timestamp |
| `supabase_user_id` | UUID | NULLABLE, UNIQUE, INDEX | **Supabase Auth user identifier (PRIMARY auth key)** |
| `stripe_customer_id` | VARCHAR(255) | NULLABLE | Stripe customer identifier for billing |
| `stripe_subscription_id` | VARCHAR(255) | NULLABLE | Stripe subscription identifier |
| `wallet_address` | VARCHAR(42) | NULLABLE, UNIQUE, INDEX | Ethereum wallet address (Phase 3.3) |
| `wallet_nonce` | VARCHAR(64) | NULLABLE | SIWE nonce for signature verification |
| `wallet_linked_at` | TIMESTAMPTZ | NULLABLE | Timestamp when wallet was linked |
| `ens_name` | VARCHAR(255) | NULLABLE, INDEX | ENS domain name (e.g., vitalik.eth) |
| `solana_wallet_address` | VARCHAR(44) | NULLABLE, UNIQUE, INDEX | Solana wallet address - base58 encoded (Phase 3.1b) |
| `solana_wallet_nonce` | VARCHAR(64) | NULLABLE | Nonce for Ed25519 signature verification |
| `solana_wallet_linked_at` | TIMESTAMPTZ | NULLABLE | Timestamp when Solana wallet was linked |

**Indexes:**
- `ix_users_email` (UNIQUE) on `email`
- `ix_users_tier` on `tier`
- `ix_users_supabase_user_id` (UNIQUE) on `supabase_user_id`
- `ix_users_wallet_address` (UNIQUE) on `wallet_address`
- `ix_users_ens_name` on `ens_name`
- `ix_users_solana_wallet_address` (UNIQUE) on `solana_wallet_address`

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
| `tier` | VARCHAR(20) | NOT NULL, DEFAULT 'free', INDEX | Current tier (free, developer, startup, professional, enterprise) |
| `monthly_scan_limit` | INTEGER | NOT NULL, DEFAULT 3 | Monthly scan limit (-1 = unlimited) |
| `monthly_scans_used` | INTEGER | NOT NULL, DEFAULT 0 | Scans used this month |
| `max_files_per_scan` | INTEGER | NOT NULL, DEFAULT 5 | Maximum files per scan (-1 = unlimited) |
| `max_loc_per_scan` | INTEGER | NOT NULL, DEFAULT 5000 | Maximum lines of code per scan (-1 = unlimited) |
| `scan_priority` | INTEGER | NOT NULL, DEFAULT 50 | Scan queue priority (5=enterprise highest, 50=free lowest) |
| `webhooks_enabled` | BOOLEAN | NOT NULL, DEFAULT false | Webhooks feature enabled (startup+) |
| `api_access_enabled` | BOOLEAN | NOT NULL, DEFAULT false | API access enabled (developer+) |
| `export_enabled` | BOOLEAN | NOT NULL, DEFAULT false | Export feature enabled (developer+) |
| `result_retention_days` | INTEGER | NOT NULL, DEFAULT 7 | Scan result retention period |
| `max_projects` | INTEGER | NOT NULL, DEFAULT 3 | Maximum projects (-1 = unlimited) |
| `monthly_api_calls_limit` | INTEGER | NOT NULL, DEFAULT 0 | Monthly API call limit (0=no access, -1=unlimited) |
| `monthly_api_calls_used` | INTEGER | NOT NULL, DEFAULT 0 | API calls used this month |
| `max_team_members` | INTEGER | NOT NULL, DEFAULT 1 | Maximum team members (-1 = unlimited) |
| `monthly_ai_explanations_limit` | INTEGER | NOT NULL, DEFAULT 0 | Monthly AI explanation quota (0=none, -1=unlimited) |
| `monthly_ai_explanations_used` | INTEGER | NOT NULL, DEFAULT 0 | AI explanations used this month |
| `quota_reset_at` | TIMESTAMPTZ | NOT NULL, DEFAULT next month | Next quota reset date (monthly or annual) |
| `last_scan_at` | TIMESTAMPTZ | NULLABLE | Last scan timestamp |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Quota record creation |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_user_quotas_user_id` on `user_id`
- `ix_user_quotas_tier` on `tier`

**Relationships:**
- One-to-one with `users` (user_id, CASCADE DELETE)

**Tier Limits (Updated January 12, 2026 - Migration 031)**:

| Tier | Scans/Mo | Files/Scan | LoC/Scan | Projects | API Calls/Mo | Team | AI Explain/Mo | Export | Retention | Priority |
|------|----------|------------|----------|----------|--------------|------|---------------|--------|-----------|----------|
| **Free** | 3 | 5 | 5,000 | 3 | 0 (no API) | 1 | 0 | No | 7 days | 50 |
| **Developer** | 100 | Unlimited | Unlimited | 5 | 1,000 | 1 | 10 | Yes | 90 days | 40 |
| **Startup** | 500 | Unlimited | Unlimited | 20 | 10,000 | 10 | 100 | Yes | 180 days | 25 |
| **Professional** | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited | 25 | 500 | Yes | 365 days | 10 |
| **Enterprise** | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited | Yes | 730 days | 5 |

**File Size Limits**:
- Free: 1 MB single / 5 MB archive
- Developer: 5 MB single / 25 MB archive
- Startup: 10 MB single / 50 MB archive
- Professional: 10 MB single / 50 MB archive
- Enterprise: 20 MB single / 100 MB archive

**Feature Access by Tier**:
- API Access: developer+
- AI Explanations: developer+ (quota-limited)
- Webhooks: startup+
- Team Management: startup+
- Organizations: professional+
- Audit Logging: professional+

**AI Explanation Quotas (Phase 5.5a - January 2026)**:
| Tier | Monthly Limit | Notes |
|------|--------------|-------|
| Free | 0 | Not available |
| Developer | 10 | Reset monthly |
| Startup | 100 | Reset monthly |
| Professional | 500 | Reset monthly |
| Enterprise | -1 | Unlimited |

**SSO/SAML**: Enterprise tier only

**Auto-Creation Trigger:**
- Trigger function `create_user_quota()` automatically creates quota record on user insert
- Quota limits set based on user's initial tier (Migration 030 values)
- Monthly/annual reset handled by background task (`src/infrastructure/tasks/quota_reset.py`)

**Quota Reset Background Task (Added January 11, 2026):**
- Runs hourly via FastAPI lifespan scheduler
- Checks users where `quota_reset_at <= now()`
- Monthly subscribers: resets to 1st of next month
- Annual subscribers: resets to subscription `current_period_end`
- Resets `monthly_scans_used` and `monthly_api_calls_used` to 0

**Quota Enforcement (Updated January 11, 2026):**

| Quota | Endpoint | HTTP Code | Error Key |
|-------|----------|-----------|-----------|
| monthly_scan_limit | POST /api/v1/scans | 402 | quota_exceeded |
| max_files_per_scan | POST /api/v1/upload | 402 | too_many_files |
| max_loc_per_scan | POST /api/v1/upload | 402 | loc_limit_exceeded |
| max_projects | POST /api/v1/projects | 403 | project_quota_exceeded |
| max_team_members | POST /api/v1/teams/{id}/members | 403 | team_member_limit_exceeded |
| export_enabled | GET /api/v1/scans/{id}/export | 403 | export_not_available |
| api_access_enabled | All /api/v1/* (via API key) | 403 | api_access_not_available |

**Quota Exceeded Error Response (HTTP 402):**
```json
{
  "detail": {
    "error": "quota_exceeded",
    "message": "You've used all 3 scans for this month",
    "tier": "free",
    "scans_used": 3,
    "scan_limit": 3,
    "scans_remaining": 0,
    "reset_date": "2026-02-01T00:00:00+00:00",
    "days_until_reset": 17,
    "upgrade_url": "/pricing",
    "upgrade_message": "Upgrade to Developer for 100 scans/month or wait until your quota resets"
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
   - Developer: 5 MB per file, 25 MB archives
   - Startup: 10 MB per file, 50 MB archives
   - Professional: 10 MB per file, 50 MB archives
   - Enterprise: 20 MB per file, 100 MB archives
   - Returns HTTP 413 if file size exceeds tier limit

2. **Files-per-Scan Limits** (from `max_files_per_scan` column):
   - Free: 25 files max per archive
   - Developer: 50 files max per archive
   - Startup: 100 files max per archive
   - Professional/Enterprise: Unlimited (-1)
   - Returns HTTP 402 if archive exceeds file count limit

3. **Language Validation**:
   - **Currently Supported:** Solidity (`.sol`), Vyper (`.vy`), Rust/Solana (`.rs`)
   - **Scanners Available:** 16/16 (10 Solidity + 2 Vyper + 4 Solana, as of December 15, 2025)
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
| `pattern_id` | VARCHAR(50) | NULLABLE | FK → vulnerability_patterns.id - Pattern classification reference |
| `pattern_code` | VARCHAR(50) | NULLABLE | BVD pattern code (e.g., 'BVD-SOLIDITY-DEFI-LIQUIDITY-001') |
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

### `user_favorites`

User favorites/pinned items for quick access (Phase 3.1b - Sprint 3, Migration 016, December 11, 2025).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique favorite identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | User who favorited the item |
| `item_type` | VARCHAR(50) | NOT NULL, INDEX | Type of item (project, contract, scan) |
| `item_id` | UUID | NOT NULL | ID of the favorited item |
| `display_order` | INTEGER | NOT NULL, DEFAULT 0 | Order for display in favorites list |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | When item was favorited |

**Item Types:**
- `project` - Favorited project
- `contract` - Favorited contract
- `scan` - Favorited scan result

**Indexes:**
- `ix_user_favorites_user_id` on `user_id`
- `ix_user_favorites_item_type` on `item_type`
- `uq_user_favorites_user_item` (UNIQUE) composite on `(user_id, item_type, item_id)` - Prevents duplicate favorites

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)

**API Endpoints:**
- `POST /api/v1/favorites` - Add a favorite
- `GET /api/v1/favorites` - List user's favorites
- `DELETE /api/v1/favorites/{type}/{id}` - Remove a favorite
- `PUT /api/v1/favorites/reorder` - Reorder favorites
- `GET /api/v1/favorites/check/{type}/{id}` - Check if item is favorited

---

### `vulnerability_annotations`

User annotations/status tracking for vulnerabilities (Phase 3.1b - Sprint 3, Migration 017, December 11, 2025).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique annotation identifier |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE, INDEX | Annotated vulnerability |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | User who created annotation |
| `status` | VARCHAR(50) | NOT NULL, INDEX | Annotation status (see enum below) |
| `note` | TEXT | NULLABLE | User notes about the vulnerability |
| `reason` | VARCHAR(255) | NULLABLE | Brief reason for status assignment |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Annotation creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Annotation Status Values:**
- `false_positive` - Marked as not a real vulnerability
- `acknowledged` - Acknowledged but not yet addressed
- `confirmed` - Confirmed as a real vulnerability
- `wont_fix` - Will not be fixed (accepted risk)
- `in_progress` - Fix is being worked on
- `fixed` - Vulnerability has been fixed

**Indexes:**
- `ix_vulnerability_annotations_vulnerability_id` on `vulnerability_id`
- `ix_vulnerability_annotations_user_id` on `user_id`
- `ix_vulnerability_annotations_status` on `status`
- `uq_vuln_annotation_user_vuln` (UNIQUE) composite on `(user_id, vulnerability_id)` - One annotation per user per vulnerability

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, CASCADE DELETE)
- One-to-many with `vulnerability_annotation_history`

**API Endpoints:**
- `POST /api/v1/annotations` - Create annotation
- `GET /api/v1/annotations/vulnerability/{id}` - Get annotation for vulnerability
- `GET /api/v1/annotations` - List user's annotations
- `DELETE /api/v1/annotations/{id}` - Delete annotation
- `GET /api/v1/annotations/{id}/history` - Get annotation history
- `GET /api/v1/annotations/scan/{id}` - Get all annotations for a scan
- `POST /api/v1/annotations/bulk` - Bulk create annotations

---

### `vulnerability_annotation_history`

Audit trail for vulnerability annotation changes (Phase 3.1b - Sprint 3, Migration 017, December 11, 2025).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique history entry identifier |
| `annotation_id` | UUID | NOT NULL, FK → vulnerability_annotations.id ON DELETE CASCADE, INDEX | Parent annotation |
| `previous_status` | VARCHAR(50) | NULLABLE | Status before change (null for creation) |
| `new_status` | VARCHAR(50) | NOT NULL | Status after change |
| `changed_by` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | User who made the change |
| `change_reason` | VARCHAR(255) | NULLABLE | Reason for the change |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Timestamp of change |

**Indexes:**
- `ix_vuln_annotation_history_annotation_id` on `annotation_id`
- `ix_vuln_annotation_history_created_at` on `created_at`

**Relationships:**
- Many-to-one with `vulnerability_annotations` (annotation_id, CASCADE DELETE)
- Many-to-one with `users` (changed_by, CASCADE DELETE)

---

### `scan_batches`

Batch scan tracking for multi-contract scan operations (Phase 3.1b - Sprint 3, Migration 018, December 11, 2025).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique batch identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | User who created the batch |
| `project_id` | UUID | NULLABLE, FK → projects.id ON DELETE SET NULL | Optional project association |
| `total_contracts` | INTEGER | NOT NULL, DEFAULT 0 | Total number of contracts in batch |
| `completed_count` | INTEGER | NOT NULL, DEFAULT 0 | Number of completed scans |
| `failed_count` | INTEGER | NOT NULL, DEFAULT 0 | Number of failed scans |
| `status` | VARCHAR(50) | NOT NULL, DEFAULT 'pending', INDEX | Batch status (pending, running, completed, partially_completed, failed) |
| `priority` | VARCHAR(20) | NOT NULL, DEFAULT 'normal' | Batch priority (low, normal, high, critical) |
| `scanner_ids` | VARCHAR(50)[] | NOT NULL | Array of scanner IDs to use |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Batch creation timestamp |
| `completed_at` | TIMESTAMPTZ | NULLABLE | Batch completion timestamp |

**Indexes:**
- `ix_scan_batches_user_id` on `user_id`
- `ix_scan_batches_status` on `status`
- `ix_scan_batches_created_at` on `created_at`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `projects` (project_id, SET NULL)
- One-to-many with `scans` (via scans.batch_id)

**API Endpoints:**
- `POST /api/v1/scans/batch` - Create batch scan for multiple contracts
- `GET /api/v1/scans/batch` - List batch scans with pagination
- `GET /api/v1/scans/batch/{batch_id}` - Get batch scan status with scan details

**Note:** The `scans` table has a `batch_id` column (FK → scan_batches.id ON DELETE SET NULL) to link individual scans to their batch.

---

### `vulnerability_patterns`

Standard vulnerability pattern definitions for classification and matching (Phase 4D).

**Pattern Code Format (Updated 2025-10-28):** All pattern codes use the `BVD-` prefix to denote **Blockchain Vulnerability Database** classification.
- **Format**: `BVD-{CATEGORY}-{NUMBER}` (e.g., "BVD-EVM-REE-001", "BVD-EVM-ACC-001")
- **Category Codes**: REE (Reentrancy), ACC (Access Control), INT (Integer), ORA (Oracle), TOK (Token), etc.
- **Historical Note**: Prior to 2025-10-28, patterns used format without BVD prefix (e.g., "REE-001")

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | VARCHAR(50) | PRIMARY KEY | Pattern identifier (e.g., "BVD-SOLIDITY-REE-001", "BVD-SOLANA-CPI-001") |
| `name` | VARCHAR(100) | NOT NULL | Pattern name (e.g., "Reentrancy Attack") |
| `description` | TEXT | NOT NULL | Detailed pattern description |
| `category` | VARCHAR(50) | NOT NULL, INDEX | Vulnerability category (e.g., "reentrancy", "cross-program-invocation") |
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

**Solana/Rust Patterns (82 patterns)** ⏳ PENDING SCANNER INTEGRATION:
- Access Control (15 patterns): BVD-SOLANA-ACC-001 through BVD-SOLANA-ACC-015
- Integer Overflow (8 patterns): BVD-SOLANA-INT-001 through BVD-SOLANA-INT-008
- PDA Issues (10 patterns): BVD-SOLANA-PDA-001 through BVD-SOLANA-PDA-010
- Plus 49 additional patterns
- **Note:** Docker images built (sol-azy, sec3-xray, trident, cargo-fuzz-solana) but scanners require Rust toolchain in orchestration pod. See Phase 3.5 scanner integration.

**Cairo/StarkNet Patterns (14 patterns)** ⏳ PENDING SCANNER INTEGRATION:
- Access Control (2 patterns): BVD-CAIRO-ACC-001, BVD-CAIRO-ACC-002
- Layer 2 Security (1 pattern): BVD-CAIRO-L2S-001
- Arithmetic (1 pattern): BVD-CAIRO-ARI-001
- Reentrancy (4 patterns): BVD-CAIRO-REE-001 through BVD-CAIRO-REE-004
- State Variables (1 pattern): BVD-CAIRO-STA-001
- Code Quality (4 patterns): BVD-CAIRO-QUA-001 through BVD-CAIRO-QUA-004
- Memory Safety (1 pattern): BVD-CAIRO-MEM-001
- **Note:** Scanner Docker images not yet built. Caracal scanner defined but not available.

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
| `pattern_id` | VARCHAR(50) | NOT NULL, FK → vulnerability_patterns.id ON DELETE CASCADE, INDEX | Associated pattern |
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

### `ml_model_metadata`

ML model versioning and continuous learning metadata (Phase 5B).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INTEGER | PRIMARY KEY, AUTO_INCREMENT | Unique record identifier |
| `model_name` | VARCHAR(100) | NOT NULL, UNIQUE | Model identifier (e.g., 'fp_classifier') |
| `current_version` | VARCHAR(50) | NULLABLE | Current model version string |
| `previous_version` | VARCHAR(50) | NULLABLE | Previous model version |
| `labels_since_train` | INTEGER | NOT NULL, DEFAULT 0 | Labels added since last training |
| `retrain_threshold` | INTEGER | NOT NULL, DEFAULT 100 | Labels needed to trigger retrain |
| `last_trained_at` | TIMESTAMPTZ | NULLABLE | Last training timestamp |
| `next_scheduled_train` | TIMESTAMPTZ | NULLABLE | Next scheduled training |
| `accuracy` | FLOAT | NULLABLE | Model accuracy metric |
| `auc` | FLOAT | NULLABLE | Area under ROC curve |
| `precision_score` | FLOAT | NULLABLE | Precision metric |
| `recall_score` | FLOAT | NULLABLE | Recall metric |
| `f1_score` | FLOAT | NULLABLE | F1 score |
| `cv_auc_mean` | FLOAT | NULLABLE | Cross-validation AUC mean |
| `cv_auc_std` | FLOAT | NULLABLE | Cross-validation AUC std dev |
| `training_samples` | INTEGER | NULLABLE | Number of training samples |
| `true_positive_count` | INTEGER | NULLABLE | True positive labels in training data |
| `false_positive_count` | INTEGER | NULLABLE | False positive labels in training data |
| `storage_backend` | VARCHAR(20) | NOT NULL, DEFAULT 'local' | Storage type (local, gcs) |
| `storage_uri` | VARCHAR(500) | NULLABLE | Model file location |
| `status` | VARCHAR(50) | NOT NULL, DEFAULT 'not_trained' | Training status |
| `error_message` | TEXT | NULLABLE | Last error message if any |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_ml_model_metadata_model_name` (BTREE on `model_name`)

**Purpose:**
- Tracks ML model versions and training history
- Triggers automatic retraining when label threshold reached
- Stores model performance metrics
- Supports local and GCS storage backends

**Initial Record:**
- Model `fp_classifier` created automatically for false positive detection

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

### `notification_channels`

User-configured notification channels for Slack, Teams, and Discord webhook integrations (CI/CD Integrations - January 2026).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique channel identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Owner user |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE CASCADE, INDEX | Organization context |
| `name` | VARCHAR(255) | NOT NULL | Channel display name |
| `channel_type` | VARCHAR(50) | NOT NULL, INDEX | Channel type: `slack`, `teams`, `discord` |
| `webhook_url` | VARCHAR(2048) | NOT NULL | Webhook endpoint URL |
| `events` | JSONB | NOT NULL | Event types to subscribe to (e.g., `["scan.completed", "vulnerability.critical"]`) |
| `filters` | JSONB | NULLABLE | Optional filters (severity, project_id, etc.) |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true, INDEX | Channel active status |
| `total_notifications` | INTEGER | NOT NULL, DEFAULT 0 | Total notifications sent |
| `successful_notifications` | INTEGER | NOT NULL, DEFAULT 0 | Successful deliveries |
| `failed_notifications` | INTEGER | NOT NULL, DEFAULT 0 | Failed deliveries |
| `last_triggered_at` | TIMESTAMPTZ | NULLABLE | Last notification attempt |
| `last_success_at` | TIMESTAMPTZ | NULLABLE | Last successful delivery |
| `last_failure_at` | TIMESTAMPTZ | NULLABLE | Last failed delivery |
| `last_error` | TEXT | NULLABLE | Last error message |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_notification_channels_user_id` on `user_id`
- `ix_notification_channels_organization_id` on `organization_id`
- `ix_notification_channels_channel_type` on `channel_type`
- `ix_notification_channels_is_active` on `is_active`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)
- One-to-many with `notification_deliveries`

**Channel Types:**
- `slack` - Slack webhooks with Block Kit formatting
- `teams` - Microsoft Teams webhooks with Adaptive Cards
- `discord` - Discord webhooks with rich embeds

**Event Types:**
- `scan.completed` - Scan finished successfully
- `scan.failed` - Scan encountered an error
- `vulnerability.critical` - Critical severity vulnerability found
- `vulnerability.high` - High severity vulnerability found

---

### `notification_deliveries`

Audit log for notification delivery attempts (CI/CD Integrations - January 2026).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique delivery identifier |
| `channel_id` | UUID | NOT NULL, FK → notification_channels.id ON DELETE CASCADE, INDEX | Parent notification channel |
| `event_type` | VARCHAR(50) | NOT NULL, INDEX | Event type (e.g., `scan.completed`) |
| `event_id` | VARCHAR(100) | NOT NULL | Unique event identifier |
| `payload` | JSONB | NOT NULL | Notification payload sent |
| `status_code` | INTEGER | NULLABLE | HTTP response status code |
| `response_body` | TEXT | NULLABLE | HTTP response body |
| `success` | BOOLEAN | NOT NULL, DEFAULT false | Delivery success status |
| `error_message` | TEXT | NULLABLE | Error message if failed |
| `duration_ms` | INTEGER | NULLABLE | Delivery duration in milliseconds |
| `triggered_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Trigger timestamp |
| `delivered_at` | TIMESTAMPTZ | NULLABLE | Successful delivery timestamp |

**Indexes:**
- `ix_notification_deliveries_channel_id` on `channel_id`
- `ix_notification_deliveries_event_type` on `event_type`
- `ix_notification_deliveries_triggered_at` on `triggered_at`

**Relationships:**
- Many-to-one with `notification_channels` (channel_id, CASCADE DELETE)

---

### `api_keys`

API keys for programmatic access (Phase 4.5).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique API key identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | Owner user |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE CASCADE | Associated organization |
| `name` | VARCHAR(255) | NOT NULL | Key name/description |
| `key_prefix` | VARCHAR(20) | NOT NULL, INDEX | Key prefix for identification (format: bso_XXXX_XXX) |
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

**API Key Scopes (implemented December 2025):**
- `contracts:read` - Read contracts
- `contracts:write` - Upload/modify contracts
- `scans:read` - Read scan results
- `scans:create` - Create new scans
- `vulnerabilities:read` - Read vulnerabilities
- `vulnerabilities:write` - Update vulnerability status
- `patterns:read` - Read vulnerability patterns
- `analytics:read` - Read analytics data
- `webhooks:read` - Read webhooks
- `webhooks:write` - Manage webhooks

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

### `teams`

**ADDED:** Migration 021 (2025-12-26) - Phase 4.5 Team Collaboration

Teams within organizations for grouping users and managing access.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique team identifier |
| `organization_id` | UUID | NOT NULL, FK → organizations.id ON DELETE CASCADE | Parent organization |
| `name` | VARCHAR(100) | NOT NULL | Team display name |
| `slug` | VARCHAR(100) | NOT NULL | URL-friendly identifier |
| `description` | TEXT | NULLABLE | Team description |
| `color` | VARCHAR(7) | NULLABLE | Hex color code (e.g., "#FF5733") |
| `created_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | User who created the team |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_teams_organization_id` on `organization_id`
- `uq_teams_org_slug` (UNIQUE) on `(organization_id, slug)`

**Relationships:**
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)
- One-to-many with `team_members`
- One-to-many with `project_team_access`

---

### `team_members`

**ADDED:** Migration 021 (2025-12-26) - Phase 4.5 Team Collaboration

Team membership with role assignment.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique membership identifier |
| `team_id` | UUID | NOT NULL, FK → teams.id ON DELETE CASCADE | Team reference |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | User reference |
| `role` | VARCHAR(20) | NOT NULL, DEFAULT 'member' | Team role (lead, member) |
| `added_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | User who added the member |
| `added_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Add timestamp |

**Indexes:**
- `ix_team_members_team_id` on `team_id`
- `ix_team_members_user_id` on `user_id`
- `uq_team_members_team_user` (UNIQUE) on `(team_id, user_id)`

**Relationships:**
- Many-to-one with `teams` (team_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, CASCADE DELETE)

**Team Roles:**
- `lead` - Manage team members, represent team in decisions
- `member` - Standard team participant

---

### `team_invites`

**ADDED:** Migration 024 (2026-01-03) - Tier Restructure & Lead Generation

Team/organization invite tracking for onboarding and lead generation.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique invite identifier |
| `inviter_user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | User who sent the invite |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE CASCADE | Organization to join |
| `team_id` | UUID | NULLABLE, FK → teams.id ON DELETE CASCADE | Team to join |
| `email` | VARCHAR(255) | NOT NULL, INDEX | Invitee email address |
| `name` | VARCHAR(255) | NULLABLE | Invitee name (for personalization) |
| `role` | VARCHAR(50) | NOT NULL, DEFAULT 'member' | Invited role |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'pending', INDEX | Invite status |
| `invite_token` | VARCHAR(64) | NOT NULL, UNIQUE, INDEX | Unique invite token |
| `expires_at` | TIMESTAMPTZ | NOT NULL | Token expiration timestamp |
| `accepted_at` | TIMESTAMPTZ | NULLABLE | When invite was accepted |
| `accepted_by_user_id` | UUID | NULLABLE, FK → users.id | User who accepted (may be new) |
| `email_sent_at` | TIMESTAMPTZ | NULLABLE | When invite email was sent |
| `email_opened_at` | TIMESTAMPTZ | NULLABLE | When invite email was opened (tracking) |
| `marketing_consent` | BOOLEAN | NOT NULL, DEFAULT false | Consent for marketing emails |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Invite creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_team_invites_email` on `email`
- `ix_team_invites_status` on `status`
- `ix_team_invites_inviter` on `inviter_user_id`
- `ix_team_invites_token` (UNIQUE) on `invite_token`
- `ix_team_invites_organization` on `organization_id`

**Relationships:**
- Many-to-one with `users` (inviter_user_id, CASCADE DELETE)
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)
- Many-to-one with `teams` (team_id, CASCADE DELETE)
- Many-to-one with `users` (accepted_by_user_id)

**Invite Status Values:**
- `pending` - Invite sent, awaiting response
- `accepted` - Invite accepted, user joined
- `expired` - Invite token expired
- `revoked` - Invite manually revoked

**Use Cases:**
- Team onboarding and invite management
- Lead generation from invited emails
- Marketing consent tracking
- Email engagement analytics
- Conversion tracking (invite → signup → active user)

---

### `project_team_access`

**ADDED:** Migration 021 (2025-12-26) - Phase 4.5 Team Collaboration

Team-level project access grants.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique access grant identifier |
| `project_id` | UUID | NOT NULL, FK → projects.id ON DELETE CASCADE | Project reference |
| `team_id` | UUID | NOT NULL, FK → teams.id ON DELETE CASCADE | Team reference |
| `access_level` | VARCHAR(20) | NOT NULL, DEFAULT 'read' | Access level (owner, write, read) |
| `granted_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | User who granted access |
| `granted_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Grant timestamp |

**Indexes:**
- `ix_project_team_access_project_id` on `project_id`
- `ix_project_team_access_team_id` on `team_id`
- `uq_project_team_access_project_team` (UNIQUE) on `(project_id, team_id)`

**Relationships:**
- Many-to-one with `projects` (project_id, CASCADE DELETE)
- Many-to-one with `teams` (team_id, CASCADE DELETE)

**Access Levels:**
- `owner` - Full control, can manage access and delete project
- `write` - Create/update contracts, scans, vulnerabilities
- `read` - View project and all contents

---

### `project_user_access`

**ADDED:** Migration 021 (2025-12-26) - Phase 4.5 Team Collaboration

Direct user-level project access grants.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique access grant identifier |
| `project_id` | UUID | NOT NULL, FK → projects.id ON DELETE CASCADE | Project reference |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | User reference |
| `access_level` | VARCHAR(20) | NOT NULL, DEFAULT 'read' | Access level (owner, write, read) |
| `granted_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | User who granted access |
| `granted_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Grant timestamp |

**Indexes:**
- `ix_project_user_access_project_id` on `project_id`
- `ix_project_user_access_user_id` on `user_id`
- `uq_project_user_access_project_user` (UNIQUE) on `(project_id, user_id)`

**Relationships:**
- Many-to-one with `projects` (project_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, CASCADE DELETE)

**Access Resolution Order:**
1. Project owner (always has full access)
2. Direct user access (project_user_access)
3. Team-based access (via team_members → project_team_access)
4. Highest access level wins across all sources

---

### `vulnerability_assignments`

**ADDED:** Migration 021 (2025-12-26) - Phase 4.5 Team Collaboration

Vulnerability remediation task assignments.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique assignment identifier |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE | Vulnerability reference |
| `assignee_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | Assigned user |
| `assigned_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | User who created assignment |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'open' | Assignment status |
| `priority` | VARCHAR(20) | NULLABLE | Priority level |
| `due_date` | TIMESTAMPTZ | NULLABLE | Due date for completion |
| `notes` | TEXT | NULLABLE | Assignment notes |
| `assigned_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Assignment creation timestamp |
| `resolved_at` | TIMESTAMPTZ | NULLABLE | Resolution timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_vuln_assignments_vulnerability_id` on `vulnerability_id`
- `ix_vuln_assignments_assignee_id` on `assignee_id`
- `ix_vuln_assignments_status` on `status`
- `ix_vuln_assignments_due_date` on `due_date`

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)
- Many-to-one with `users` (assignee_id, CASCADE DELETE)

**Assignment Status Values:**
- `open` - Initial state, work not started
- `in_progress` - Work underway
- `resolved` - Issue fixed
- `wont_fix` - Decision to not fix

**Priority Levels:**
- `critical` - Immediate action required
- `high` - Important issues for next sprint
- `medium` - Standard priority items
- `low` - Nice-to-have fixes

---

### `quality_gates`

**ADDED:** Migration 032 (2026-01-12) - Phase 5.5c CI/CD Integration

Quality gate configurations for CI/CD pipeline integration.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique quality gate identifier |
| `project_id` | UUID | NULLABLE, FK → projects.id ON DELETE CASCADE | Project reference (null = org default) |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE CASCADE | Organization reference |
| `name` | VARCHAR(255) | NOT NULL | Quality gate name |
| `description` | TEXT | NULLABLE | Gate description |
| `block_on_critical` | BOOLEAN | NOT NULL, DEFAULT true | Block pipeline on critical vulnerabilities |
| `block_on_high` | BOOLEAN | NOT NULL, DEFAULT false | Block pipeline on high vulnerabilities |
| `max_critical` | INTEGER | NOT NULL, DEFAULT 0 | Maximum critical vulnerabilities allowed |
| `max_high` | INTEGER | NOT NULL, DEFAULT -1 | Maximum high vulnerabilities (-1 = unlimited) |
| `max_medium` | INTEGER | NOT NULL, DEFAULT -1 | Maximum medium vulnerabilities (-1 = unlimited) |
| `max_low` | INTEGER | NOT NULL, DEFAULT -1 | Maximum low vulnerabilities (-1 = unlimited) |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true | Gate activation status |
| `created_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | User who created the gate |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_quality_gates_project_id` on `project_id`
- `ix_quality_gates_organization_id` on `organization_id`
- Unique constraint on `(project_id)` WHERE `project_id IS NOT NULL`
- Unique constraint on `(organization_id)` WHERE `organization_id IS NOT NULL AND project_id IS NULL`

**Relationships:**
- Many-to-one with `projects` (project_id, CASCADE DELETE)
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)
- Many-to-one with `users` (created_by, SET NULL)

**Blocking Rules:**
- `block_on_critical` - Fails if ANY critical vulnerability found
- `block_on_high` - Fails if ANY high vulnerability found

**Threshold Rules:**
- `max_critical >= 0` - Fails if count exceeds threshold
- `max_high >= 0` - Fails if count exceeds threshold
- `-1` means unlimited (no threshold check)

---

### `quality_gate_evaluations`

**ADDED:** Migration 032 (2026-01-12) - Phase 5.5c CI/CD Integration

Quality gate evaluation history for audit trail and CI/CD integration.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique evaluation identifier |
| `quality_gate_id` | UUID | NOT NULL, FK → quality_gates.id ON DELETE CASCADE | Quality gate reference |
| `scan_id` | UUID | NOT NULL, FK → scans.id ON DELETE CASCADE | Scan evaluated |
| `project_id` | UUID | NOT NULL, FK → projects.id ON DELETE CASCADE | Project reference |
| `status` | VARCHAR(20) | NOT NULL | Evaluation status |
| `passed` | BOOLEAN | NOT NULL | Whether gate passed |
| `critical_count` | INTEGER | NOT NULL, DEFAULT 0 | Critical vulnerabilities count |
| `high_count` | INTEGER | NOT NULL, DEFAULT 0 | High vulnerabilities count |
| `medium_count` | INTEGER | NOT NULL, DEFAULT 0 | Medium vulnerabilities count |
| `low_count` | INTEGER | NOT NULL, DEFAULT 0 | Low vulnerabilities count |
| `violations` | JSONB | NOT NULL, DEFAULT '[]' | Array of violation details |
| `triggered_by` | VARCHAR(50) | NULLABLE | Trigger source (ci, manual, webhook) |
| `ci_context` | JSONB | NULLABLE | CI/CD context data (branch, commit, PR, etc.) |
| `evaluated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Evaluation timestamp |

**Indexes:**
- `ix_qg_evals_quality_gate_id` on `quality_gate_id`
- `ix_qg_evals_scan_id` on `scan_id`
- `ix_qg_evals_project_id` on `project_id`
- `ix_qg_evals_evaluated_at` on `evaluated_at`

**Relationships:**
- Many-to-one with `quality_gates` (quality_gate_id, CASCADE DELETE)
- Many-to-one with `scans` (scan_id, CASCADE DELETE)
- Many-to-one with `projects` (project_id, CASCADE DELETE)

**Evaluation Status Values:**
- `passing` - Gate passed, no violations
- `failing` - Gate failed, one or more violations
- `pending` - Evaluation in progress

**Violations JSONB Structure:**
```json
[
  {
    "rule": "max_critical",
    "threshold": 0,
    "actual": 2,
    "severity": "critical",
    "message": "Critical vulnerabilities (2) exceed threshold (0)"
  }
]
```

**CI Context JSONB Structure:**
```json
{
  "branch": "main",
  "commit": "abc123",
  "pr": 42,
  "workflow": "Security Scan",
  "run_id": "12345"
}
```

---

### `comments`

**ADDED:** Migration 021 (2025-12-26) - Phase 4.5 Team Collaboration

Polymorphic comments on various entities.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique comment identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | Comment author |
| `entity_type` | VARCHAR(50) | NOT NULL | Entity type (vulnerability, scan, contract, project) |
| `entity_id` | UUID | NOT NULL | Entity UUID |
| `content` | TEXT | NOT NULL | Comment content |
| `mentions` | JSONB | NOT NULL, DEFAULT '[]' | Array of mentioned user UUIDs |
| `parent_id` | UUID | NULLABLE, FK → comments.id ON DELETE CASCADE | Parent comment for threading |
| `is_edited` | BOOLEAN | NOT NULL, DEFAULT false | Edit flag |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_comments_user_id` on `user_id`
- `ix_comments_entity` on `(entity_type, entity_id)`
- `ix_comments_parent_id` on `parent_id`
- `ix_comments_created_at` on `created_at`
- GIN index on `mentions` for array queries

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Self-referential with `comments` (parent_id, CASCADE DELETE)

**Supported Entity Types:**
- `vulnerability` - Comments on vulnerabilities
- `scan` - Comments on scan results
- `contract` - Comments on contracts
- `project` - Comments on projects

**Threading Model:**
- Single-level threading only
- Top-level comments can have replies
- Replies cannot have nested replies
- Parent validation ensures same entity

---

## ENUM Types

### `contract_language`

Supported blockchain programming languages.

**Values (✅ = Scanner Available, ⏳ = Planned):**
- `solidity` - Ethereum/EVM smart contracts ✅ (10 scanners)
- `vyper` - Ethereum/EVM (Python-like) ✅ (2 scanners: Slither-Vyper, Moccasin)
- `rust` - Solana programs ⏳ (Docker images built, scanners pending)
- `move` - Aptos/Sui smart contracts ⏳
- `cairo` - StarkNet contracts ⏳
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

> **Important**: PostgreSQL enum values are **case-sensitive**. All values must be **lowercase**. Scanner integrations must convert uppercase values (e.g., `"HIGH"`) to lowercase (e.g., `"high"`) before inserting into the database.

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

**Cursor Pagination Indexes (Migration 029):**
- `ix_vulnerabilities_detected_at_id_cursor` on `vulnerabilities(detected_at DESC, id DESC)` - Cursor pagination
- `ix_scans_created_at_id_cursor` on `scans(created_at DESC, id DESC)` - Cursor pagination
- `ix_audit_logs_created_at_id_cursor` on `audit_logs(created_at DESC, id DESC)` - Cursor pagination

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

**Document Version:** 1.7.0
**Last Updated:** December 11, 2025 (Added favorites and annotations tables, 36 total tables)
**Maintained By:** BlockSecOps Team

---

## Recent Schema Changes

### Migration 017: Vulnerability Annotations (December 11, 2025)
- Added `vulnerability_annotations` table for tracking vulnerability status
- Added `vulnerability_annotation_history` table for audit trail
- Added AnnotationStatus enum: false_positive, acknowledged, confirmed, wont_fix, in_progress, fixed
- Supports bulk annotation operations

### Migration 016: User Favorites (December 11, 2025)
- Added `user_favorites` table for pinned items
- Supports projects, contracts, and scans as favorite types
- Includes display ordering for custom sort

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

---

## Phase 5 Summary

**Phase 5: AI/ML Features** was completed on December 27, 2025.

### ML-Related Fields

The following database fields support Phase 5 ML features:

#### Vulnerabilities Table (ML Fields)

| Field | Type | Purpose |
|-------|------|---------|
| `false_positive_score` | DOUBLE PRECISION | ML-predicted probability of false positive (0.0-1.0) |
| `classification_confidence` | DOUBLE PRECISION | Pattern match confidence score (0.0-1.0) |
| `classification_method` | VARCHAR(20) | Classification method: 'rule_based', 'ml_based', or 'hybrid' |
| `tool_consensus_score` | DOUBLE PRECISION | Consensus score across multiple scanners (0.0-1.0) |
| `fingerprint_semantic` | VARCHAR(64) | Base64-encoded semantic embedding (384-dim vector) |
| `user_classification` | VARCHAR(20) | User override classification for training data |
| `user_feedback` | TEXT | User feedback/reason for classification |

#### Vulnerability Patterns Table (ML Fields)

| Field | Type | Purpose |
|-------|------|---------|
| `false_positive_rate` | DOUBLE PRECISION | Historical FP rate for this pattern |
| `semantic_description` | TEXT | Text description for semantic embedding |
| `keywords` | TEXT[] | Keywords for similarity matching |

### ML Feature to Field Mapping

| ML Feature | Database Fields Used |
|------------|---------------------|
| **Risk Scoring** | `severity`, `false_positive_score`, `tool_consensus_score`, `classification_confidence` |
| **Confidence Scoring** | `false_positive_score`, `confidence`, `classification_confidence`, `tool_consensus_score` |
| **Smart Prioritization** | `severity`, `false_positive_score`, `tool_consensus_score`, `pattern_code` |
| **False Positive Detection** | All vulnerability fields (30+ features extracted) |
| **Semantic Deduplication** | `fingerprint_semantic`, `title`, `description`, `code_snippet` |

### Training Data Storage

Training labels for the FP classifier are stored in the `vulnerability_classifications` table:

| Field | Type | Purpose |
|-------|------|---------|
| `vulnerability_id` | UUID | Reference to vulnerability |
| `was_actually_vulnerable` | BOOLEAN | Ground truth label (true = real issue) |
| `user_feedback` | TEXT | User's reason for classification |
| `exploitability_score` | DOUBLE PRECISION | User-assessed exploitability (0.0-1.0) |
| `created_at` | TIMESTAMP | When label was created |
| `updated_at` | TIMESTAMP | When label was updated |

### Related Documentation

- **Implementation Summary**: `/docs/changelogs/PHASE-5-AI-ML-IMPLEMENTATION-2025-12-27.md`
- **Planning Summary**: `/docs/changelogs/PHASE-5-AI-ML-PLANNING-2025-12-27.md`
- **Task Documentation**: `/TaskDocs-BlockSecOps/phases/05-phase-5-ai-ml/`
- **ML Development Standards**: `/docs/standards/ml-development.md`
- **Feature Tests**: `/docs/feature-tests/27-ai-ml-features.md`

---

**Last Updated**: December 27, 2025
