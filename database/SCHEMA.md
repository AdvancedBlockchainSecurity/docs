# Apogee Database Schema

**Database:** PostgreSQL 15.4
**Database Name:** `solidity_security`
**Schema:** `public`
**Timezone:** UTC

> **Important Note on Database Naming:**
> The database is named `solidity_security`, NOT `blocksecops`. This name was established during initial platform development when the focus was solely on Solidity security scanning. The name has been retained for backward compatibility and to avoid migration complexity. All services, connection strings, and documentation should reference `solidity_security`.
>
> **Verified:** March 1, 2026 (Current stats: 184 contracts, 555 scans, 7,342 vulnerabilities, 14 users, 91 tables in `solidity_security` database)

## Table of Contents

1. [Overview](#overview)
2. [Entity Relationship Diagram](#entity-relationship-diagram)
3. [Tables](#tables)
4. [ENUM Types](#enum-types)
5. [Indexes](#indexes)
6. [Relationships](#relationships)

---

## Overview

The Apogee database supports a comprehensive smart contract security scanning platform with:

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
- **Platform admin:** Admin sessions with MFA, IP binding, and permanent admin audit logs (Phase 4.6 - January 2026). Admin portal isolated to separate application (February 2026)
- **ML Data Strategy:** ToS consent tracking, ML training data provenance, GDPR data requests (January 2026)
- **Support tickets:** User support ticket submissions with JIRA integration (February 2026)
- **ML Data Preservation:** Soft delete vulnerabilities, contract archival, implicit labeling for ML training (February 2026)
- **Multi-class Classification:** 4-class vulnerability classification (confirmed, false_positive, wont_fix, needs_review) (February 2026)
- **Deduplication Audit Fixes:** Performance indexes, FK cascade behavior fix for canonical_finding_id (February 2026)
- **AI Copilot:** Conversation threads, messages, repair suggestions, review suggestions and feedback (February 2026)
- **ML/Training Pipeline:** Active learning queue, weak labels, scanner quality metrics, training data provenance (February 2026)
- **Intelligence Enrichment:** CVE database, real-world exploit records, PoC exploit generation, vulnerability classifications, interactions, and trends (February 2026)
- **Contract Monitoring:** On-chain monitored contracts with alert detection and acknowledgment (February 2026)
- **Contracts Metadata:** User-defined contract tags and associations (February 2026)
- **Invariant Generation:** AI-generated invariants and reusable invariant templates (February 2026)
- **Auth/Billing Extensions:** Service accounts, Stripe subscriptions, billing details, IDE tokens, support impersonation sessions (February 2026)
- **Compliance:** ToS consent records, GDPR data requests (February 2026)
- **Alerts & Feedback:** On-chain security alerts and general user feedback submissions (February 2026)
- **JIRA Integration:** Project mappings and bidirectional issue sync records (February 2026)
- **Referral System:** User referral codes, referral tracking, reward management, and admin-configurable platform settings (March 2026)

**Total Tables:** 91 (excluding alembic_version)

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
- `vulnerability_patterns`: 415 standardized patterns across 4 ecosystems
- `pattern_tool_mappings`: 707 scanner detector → pattern mappings (16 scanners)
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
| `tier` | VARCHAR(20) | NOT NULL, DEFAULT 'developer', INDEX | User tier (developer, team, growth, enterprise) |
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
- One-to-many with `admin_sessions` (Phase 4.6)
- One-to-many with `admin_audit_logs` (Phase 4.6)

**Platform Admin Columns (Phase 4.6 - January 2026):**

> **Admin Portal Isolation (February 2026):** Admin functionality has been moved to a separate admin portal application (`admin.0xapogee.local` / `admin.0xapogee.com`). The admin portal shares the same Supabase project and database as the customer dashboard, but security is enforced through IP allowlisting, mandatory MFA, and admin_role checks. Admin routes have been removed from the main dashboard (`app.0xapogee.local`).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `admin_role` | VARCHAR(50) | NULLABLE, INDEX | Admin role (super_admin, platform_admin, support_admin) |
| `admin_mfa_enabled` | BOOLEAN | NOT NULL, DEFAULT false | MFA setup complete |
| `admin_mfa_secret` | VARCHAR(255) | NULLABLE | Encrypted TOTP secret (Fernet encryption) |
| `admin_last_activity` | TIMESTAMPTZ | NULLABLE | Last admin panel activity |
| `admin_session_ip` | VARCHAR(45) | NULLABLE | Current session IP (for binding) |
| `admin_created_by` | UUID | NULLABLE, FK → users.id | Who granted admin access |
| `admin_created_at` | TIMESTAMPTZ | NULLABLE | When admin access was granted |
| `mfa_failed_attempts` | INTEGER | NOT NULL, DEFAULT 0 | Failed MFA attempt counter (resets on success) |
| `mfa_locked_until` | TIMESTAMPTZ | NULLABLE | Lockout expiry (15 min after 5 failures) |
| `mfa_last_failed_at` | TIMESTAMPTZ | NULLABLE | Last failed MFA attempt (for rate limiting) |

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

### `admin_sessions`

Admin panel sessions with MFA verification and IP binding (Phase 4.6 - January 2026).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique session identifier |
| `user_id` | UUID | NOT NULL, FK → users.id, INDEX | Admin user |
| `session_token` | VARCHAR(255) | NOT NULL, UNIQUE, INDEX | Hashed session token (SHA-256) |
| `ip_address` | VARCHAR(45) | NOT NULL | Client IP (for session binding) |
| `user_agent` | VARCHAR(500) | NULLABLE | Browser user agent |
| `mfa_verified` | BOOLEAN | NOT NULL, DEFAULT false | MFA verification status |
| `mfa_verified_at` | TIMESTAMPTZ | NULLABLE | MFA verification timestamp |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Session creation time |
| `expires_at` | TIMESTAMPTZ | NOT NULL | Session expiration (30 min inactivity) |
| `last_activity` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last activity timestamp |
| `is_revoked` | BOOLEAN | NOT NULL, DEFAULT false | Revocation status |
| `revoked_at` | TIMESTAMPTZ | NULLABLE | Revocation timestamp |
| `revoked_reason` | VARCHAR(255) | NULLABLE | Reason for revocation |

**Indexes:**
- `ix_admin_sessions_user_id` on `user_id`
- `ix_admin_sessions_session_token` (UNIQUE) on `session_token`
- `ix_admin_sessions_expires_at` on `expires_at`

**Relationships:**
- Many-to-one with `users` (user_id)

**Security Notes:**
- Sessions are IP-bound (invalidated on IP change)
- Maximum session duration: 8 hours
- Inactivity timeout: 30 minutes
- Session tokens are hashed before storage

---

### `admin_audit_logs`

Permanent audit log of all admin actions (Phase 4.6 - January 2026). **Never purged.**

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique log identifier |
| `admin_user_id` | UUID | NOT NULL, FK → users.id, INDEX | Admin who performed action |
| `admin_role` | VARCHAR(50) | NOT NULL | Admin's role at time of action |
| `action` | VARCHAR(100) | NOT NULL, INDEX | Action identifier (e.g., user.tier_changed) |
| `target_type` | VARCHAR(50) | NULLABLE | Entity type (user, organization, system) |
| `target_id` | UUID | NULLABLE, INDEX | Target entity ID |
| `ip_address` | VARCHAR(45) | NOT NULL | Admin's IP address |
| `user_agent` | VARCHAR(500) | NULLABLE | Browser user agent |
| `request_id` | VARCHAR(100) | NULLABLE | Request correlation ID |
| `old_values` | JSONB | NULLABLE | State before change |
| `new_values` | JSONB | NULLABLE | State after change |
| `reason` | TEXT | NULLABLE | Required for destructive actions |
| `success` | BOOLEAN | NOT NULL, DEFAULT true | Action success status |
| `error_message` | TEXT | NULLABLE | Error message if failed |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Action timestamp |

**Indexes:**
- `ix_admin_audit_logs_admin_user_id` on `admin_user_id`
- `ix_admin_audit_logs_action` on `action`
- `ix_admin_audit_logs_target_id` on `target_id`
- `ix_admin_audit_logs_created_at` on `created_at`
- `ix_admin_audit_logs_target_type_action` on (`target_type`, `action`)

**Relationships:**
- Many-to-one with `users` (admin_user_id)

**Retention Policy:**
- Logs are **never purged** (permanent record)
- Required for compliance and incident investigation
- All admin actions logged regardless of success/failure

---

### `user_quotas`

User quota tracking for tier-based limits (Phase 3.1a - Freemium Model). Auto-created via trigger when user is created.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique quota identifier |
| `user_id` | UUID | NOT NULL, UNIQUE, FK → users.id ON DELETE CASCADE | Associated user |
| `tier` | VARCHAR(20) | NOT NULL, DEFAULT 'developer', INDEX | Current tier (developer, team, growth, enterprise) |
| `monthly_scan_limit` | INTEGER | NOT NULL, DEFAULT 3 | Monthly scan limit (-1 = unlimited) |
| `monthly_scans_used` | INTEGER | NOT NULL, DEFAULT 0 | Scans used this month |
| `max_files_per_scan` | INTEGER | NOT NULL, DEFAULT 5 | Maximum files per scan (-1 = unlimited) |
| `max_loc_per_scan` | INTEGER | NOT NULL, DEFAULT 5000 | Maximum lines of code per scan (-1 = unlimited) |
| `scan_priority` | INTEGER | NOT NULL, DEFAULT 50 | Scan queue priority (5=enterprise highest, 50=developer lowest) |
| `webhooks_enabled` | BOOLEAN | NOT NULL, DEFAULT false | Webhooks feature enabled (growth+) |
| `api_access_enabled` | BOOLEAN | NOT NULL, DEFAULT false | API access enabled (team+) |
| `export_enabled` | BOOLEAN | NOT NULL, DEFAULT false | Export feature enabled (team+) |
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

**Tier Limits (Updated January 22, 2026 - New 4-Tier Pricing Model)**:

| Tier | Price | Scans/Mo | Files/Scan | LoC/Scan | Projects | API Calls/Mo | Team | AI Explain/Mo | Export | Retention | Priority |
|------|-------|----------|------------|----------|----------|--------------|------|---------------|--------|-----------|----------|
| **Developer** | $0 | 10 | 5 | 5,000 | 3 | 0 (no API) | 1 | 0 | No | 7 days | 50 |
| **Team** | $299/mo | 100 | Unlimited | Unlimited | 10 | 1,000 | 5 | 10 | Yes | 90 days | 40 |
| **Growth** | $699/mo | 500 | Unlimited | Unlimited | 20 | 10,000 | 10 | 100 | Yes | 180 days | 25 |
| **Enterprise** | $1,999+/mo | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited | Unlimited | Yes | 730 days | 5 |

**File Size Limits**:
- Developer: 1 MB single / 5 MB archive ($0 tier)
- Team: 5 MB single / 25 MB archive ($299/mo)
- Growth: 10 MB single / 50 MB archive ($699/mo)
- Enterprise: 20 MB single / 100 MB archive ($1,999+/mo)

**Feature Access by Tier**:
- API Access: team+ ($299/mo)
- AI Explanations: team+ (quota-limited)
- Webhooks: growth+ ($699/mo)
- Team Management: growth+
- Organizations: enterprise ($1,999+/mo)
- Audit Logging: enterprise

**AI Explanation Quotas (Phase 5.5a - January 2026)**:
| Tier | Price | Monthly Limit | Notes |
|------|-------|--------------|-------|
| Developer | $0 | 0 | Not available |
| Team | $299/mo | 10 | Reset monthly |
| Growth | $699/mo | 100 | Reset monthly |
| Enterprise | $1,999+/mo | -1 | Unlimited |

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
    "tier": "developer",
    "scans_used": 3,
    "scan_limit": 3,
    "scans_remaining": 0,
    "reset_date": "2026-02-01T00:00:00+00:00",
    "days_until_reset": 17,
    "upgrade_url": "/pricing",
    "upgrade_message": "Upgrade to Team for 100 scans/month or wait until your quota resets"
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
   - Developer: 1 MB per file, 5 MB archives ($0)
   - Team: 5 MB per file, 25 MB archives ($299/mo)
   - Growth: 10 MB per file, 50 MB archives ($699/mo)
   - Enterprise: 20 MB per file, 100 MB archives ($1,999+/mo)
   - Returns HTTP 413 if file size exceeds tier limit

2. **Files-per-Scan Limits** (from `max_files_per_scan` column):
   - Developer: 25 files max per archive ($0)
   - Team: 50 files max per archive ($299/mo)
   - Growth: 100 files max per archive ($699/mo)
   - Enterprise: Unlimited (-1) ($1,999+/mo)
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
    "message": "File size (2.5 MB) exceeds developer tier limit of 1 MB for files",
    "tier": "developer",
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
    "message": "Archive contains 30 files, exceeding developer tier limit of 25 files per scan",
    "tier": "developer",
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
| `source_hash` | VARCHAR(64) | NULLABLE, INDEX | SHA-256 hash of source code (Migration 063) |
| `source_repo_url` | VARCHAR(500) | NULLABLE | External repo URL for re-download (GitHub/GitLab) |
| `source_commit_hash` | VARCHAR(40) | NULLABLE | Git commit hash for external reference |
| `source_file_path` | VARCHAR(500) | NULLABLE | File path within external repository |
| `is_archived` | BOOLEAN | NOT NULL, DEFAULT false | Contract source has been archived |
| `archived_at` | TIMESTAMPTZ | NULLABLE | When source was archived |

**Contract Archival (Migration 063 - February 2026)**:

Contracts can be archived to preserve ML training data while removing source code:
- `source_hash` enables verification when restoring from external sources
- `source_repo_url` + `source_commit_hash` allow re-download from GitHub/GitLab
- When archived, `source_code` is set to NULL but vulnerabilities and labels are preserved
- See `contract_archives` table for compressed source backup

**Indexes:**
- `ix_contracts_user_id` on `user_id`
- `ix_contracts_address` on `address`
- `ix_contracts_language` on `language`
- `idx_contracts_framework` on `framework` (partial, WHERE framework IS NOT NULL) - Phase 3.2
- `ix_contracts_source_hash` on `source_hash` (Migration 063)

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
| `priority` | INTEGER | NOT NULL, DEFAULT 50, INDEX | Scan priority (lower = higher priority). Enterprise=5, Growth=25, Team=40, Developer=50 |
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
| `is_primary` | BOOLEAN | NOT NULL, DEFAULT true | Primary instance in deduplication group. **API alias:** Serialized as `is_canonical` in API responses (v0.29.19+, via Pydantic `validation_alias`) |
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
| `deleted_at` | TIMESTAMPTZ | NULLABLE, INDEX | Soft delete timestamp (Migration 062) |
| `deleted_by` | UUID | NULLABLE, FK → users.id | User who soft-deleted this vulnerability |
| `deletion_reason` | VARCHAR(50) | NULLABLE | Reason: user_action, contract_deleted, scan_deleted |

**Soft Delete Support (Migration 062 - February 2026)**:

Vulnerabilities support soft deletion to preserve ML training data. Soft-deleted vulnerabilities:
- Are excluded from normal API queries by default
- Can be included with `?include_deleted=true` parameter
- Retain all labels and annotations for ML training
- Are automatically soft-deleted when parent contract is deleted (with `deletion_reason='contract_deleted'`)

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
- `ix_vulnerabilities_deleted_at` on `deleted_at` (Migration 062)
- `ix_vulnerabilities_active` partial index on active vulnerabilities WHERE `deleted_at IS NULL` (Migration 062)
- `ix_vulnerabilities_classification_confidence` on `classification_confidence` (Dedup Audit 2026-02-04)
- `ix_vulnerabilities_classification_method` on `classification_method` (Dedup Audit 2026-02-04)
- `ix_vulnerabilities_deduplication_strategy` on `deduplication_strategy` (Dedup Audit 2026-02-04)
- `ix_vulnerabilities_similarity_score` on `similarity_score` (Dedup Audit 2026-02-04)

**Relationships:**
- Many-to-one with `scans` (scan_id, CASCADE DELETE - vulnerabilities are deleted when parent scan is deleted)
- Many-to-one with `contracts` (contract_id)
- Many-to-one with `deduplication_groups` (deduplication_group_id, SET NULL on delete) (Dedup Audit 2026-02-04)
- Many-to-one with `vulnerability_patterns` (pattern_id, SET NULL on delete) (Dedup Audit 2026-02-04)
- One-to-many with `implicit_labels` (vulnerability_id, Migration 064)

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

**Pattern Code Format (Updated 2026-02-03):** All pattern codes use the `BVD-` prefix to denote **Blockchain Vulnerability Database** classification.
- **Format**: `BVD-{LANGUAGE}-{CATEGORY}-{NUMBER}` (e.g., "BVD-SOLIDITY-REE-001", "BVD-VYPER-ACC-001", "BVD-SOLANA-CPI-001")
- **Language Prefixes**: SOLIDITY (EVM/Solidity), VYPER (Vyper), SOLANA (Solana/Rust)
- **Category Codes**: REE (Reentrancy), ACC (Access Control), INT (Integer), ORA (Oracle), TOK (Token), CPI (Cross-Program Invocation), etc.
- **Historical Note**: Prior to 2025-10-28, patterns used format without BVD prefix (e.g., "REE-001"). Prior to 2026-02-03, Solidity patterns used `BVD-EVM-` prefix.

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
- Reentrancy (15 patterns): BVD-SOLIDITY-REE-001 through BVD-SOLIDITY-REE-015
- Access Control (18 patterns): BVD-SOLIDITY-ACC-001 through BVD-SOLIDITY-ACC-018
- Integer/Arithmetic (12 patterns): BVD-SOLIDITY-INT-001 through BVD-SOLIDITY-INT-012
- External Calls (10 patterns): BVD-SOLIDITY-EXT-001 through BVD-SOLIDITY-EXT-010
- State Variables (8 patterns): BVD-SOLIDITY-STA-001 through BVD-SOLIDITY-STA-008
- Gas Optimization (15 patterns): BVD-SOLIDITY-GAS-001 through BVD-SOLIDITY-GAS-015
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
| `canonical_finding_id` | UUID | NULLABLE, FK → vulnerabilities.id ON DELETE SET NULL | Primary/canonical finding reference (renamed from `primary_vulnerability_id` in migration 012, changed to SET NULL in Dedup Audit 2026-02-04) |
| `contract_id` | UUID | NOT NULL, FK → contracts.id ON DELETE CASCADE | Associated contract |
| `pattern_code` | VARCHAR(50) | NULLABLE, FK → vulnerability_patterns.id ON DELETE SET NULL | Pattern code (e.g., "BVD-SOLIDITY-REE-001") (renamed from `pattern_id` in migration 012) |
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
- One-to-many with `vulnerabilities` (vulnerabilities reference deduplication_group_id, with ORM `vulnerabilities` relationship for reverse navigation - Dedup Audit 2026-02-04)
- Many-to-one with `vulnerabilities` (canonical_finding_id references a single vulnerability as the "primary", SET NULL on delete)

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
Pattern: BVD-SOLIDITY-REE-001 (Reentrancy)
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
| `tier` | VARCHAR(50) | NOT NULL, DEFAULT 'developer' | Organization tier (developer, team, growth, enterprise) |
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
| `secret` | VARCHAR(255) | NOT NULL | HMAC-SHA256 signing secret (**encrypted at rest** with Fernet AES-128-CBC since v0.29.21; plaintext returned only on create/rotate) |
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
| `webhook_url` | VARCHAR(2048) | NOT NULL | Webhook endpoint URL (**masked in API responses** since v0.29.21; SSRF-validated on create/update) |
| `events` | JSONB | NOT NULL | Event types to subscribe to (e.g., `["scan.completed", "vulnerability.critical"]`) |
| `filters` | JSONB | NULLABLE | Optional filters (**typed as `Dict[str, str]`** since v0.29.21; allowed keys: `min_severity`, `project_id`) |
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

### `support_tickets`

User support ticket submissions with optional JIRA integration (Phase 7 - February 2026, Migration 061).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique ticket identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | User who submitted the ticket |
| `category` | VARCHAR(50) | NOT NULL, INDEX | Ticket category (bug, billing, feature_request, security, general) |
| `priority` | VARCHAR(20) | NOT NULL, DEFAULT 'medium' | Priority level (low, medium, high, urgent) |
| `subject` | VARCHAR(255) | NOT NULL | Ticket subject line |
| `description` | TEXT | NOT NULL | Detailed description of the issue |
| `user_email` | VARCHAR(255) | NOT NULL | User's email at submission time |
| `user_tier` | VARCHAR(20) | NOT NULL | User's subscription tier at submission time |
| `page_url` | VARCHAR(500) | NULLABLE | URL where ticket was submitted from |
| `user_agent` | VARCHAR(500) | NULLABLE | Browser/client user agent |
| `jira_issue_key` | VARCHAR(50) | NULLABLE, INDEX | JIRA issue key (e.g., SUPPORT-123) |
| `jira_issue_url` | VARCHAR(2048) | NULLABLE | Full URL to JIRA issue |
| `jira_sync_status` | VARCHAR(20) | NOT NULL, DEFAULT 'pending' | Sync status (pending, synced, failed, disabled) |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'open', INDEX | Ticket status (open, in_progress, resolved, closed) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Categories:**
- `bug` - Software defects or issues
- `billing` - Payment and subscription questions
- `feature_request` - New feature suggestions
- `security` - Security concerns or vulnerabilities
- `general` - General inquiries

**JIRA Sync Status:**
- `pending` - Awaiting JIRA sync
- `synced` - Successfully created in JIRA
- `failed` - JIRA sync failed (will retry)
- `disabled` - JIRA integration not configured

**Indexes:**
- `ix_support_tickets_user_id` on `user_id`
- `ix_support_tickets_status` on `status`
- `ix_support_tickets_jira_issue_key` on `jira_issue_key`
- `ix_support_tickets_created_at` on `created_at`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)

**Rate Limiting:**
- 5 tickets per day per user

**API Endpoint:**
- `POST /api/v1/support-tickets` - Submit a support ticket

**Ticket Reference Format:**
- Generated as `BSO-XXXXXXXX` (8 character alphanumeric)
- Derived from UUID for uniqueness

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

### `contract_archives`

Archive records for contracts with source code removed (Migration 063 - February 2026).

Enables ML training data preservation by allowing contract source to be archived while maintaining restoration capability.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique archive identifier |
| `contract_id` | UUID | NOT NULL, UNIQUE, FK → contracts.id ON DELETE CASCADE | Associated contract |
| `source_hash` | VARCHAR(64) | NOT NULL | SHA-256 hash for verification |
| `provider` | VARCHAR(50) | NULLABLE | External provider: github, gitlab |
| `repo_full_name` | VARCHAR(500) | NULLABLE | Repository name (owner/repo) |
| `commit_hash` | VARCHAR(40) | NULLABLE | Git commit hash |
| `file_path` | VARCHAR(500) | NULLABLE | File path within repository |
| `compressed_source` | BYTEA | NULLABLE | Gzip-compressed source (fallback) |
| `archived_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Archive timestamp |
| `archived_by` | UUID | NOT NULL, FK → users.id | User who archived |
| `last_restored_at` | TIMESTAMPTZ | NULLABLE | Last restoration timestamp |
| `restore_count` | INTEGER | NOT NULL, DEFAULT 0 | Number of restorations |

**Indexes:**
- `ix_contract_archives_contract_id` (UNIQUE) on `contract_id`
- `ix_contract_archives_source_hash` on `source_hash`
- `ix_contract_archives_provider` on `provider`

**Relationships:**
- One-to-one with `contracts` (contract_id, CASCADE DELETE)
- Many-to-one with `users` (archived_by)

**Archive Strategy:**
1. If contract has external reference (GitHub integration), store repo/commit/path
2. Otherwise, store gzip-compressed source as fallback
3. Always store `source_hash` for verification on restore

**Restoration Priority:**
1. Try external provider (GitHub/GitLab API)
2. Fall back to compressed source
3. Verify hash matches before restoring

---

### `implicit_labels`

Implicit labels inferred from user actions for ML training (Migration 064 - February 2026).

Stores labels automatically generated from user actions such as status changes, providing additional training data without requiring explicit user labeling.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique label identifier |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE, INDEX | Associated vulnerability |
| `label` | VARCHAR(50) | NOT NULL, INDEX | Label: confirmed, false_positive, wont_fix |
| `confidence` | FLOAT | NOT NULL | Confidence score 0.0-1.0 |
| `source` | VARCHAR(50) | NOT NULL, INDEX | Source: status_change, view_pattern, etc. |
| `action_type` | VARCHAR(100) | NOT NULL | Action type: status:open->fixed, etc. |
| `previous_value` | VARCHAR(100) | NULLABLE | Previous value before action |
| `new_value` | VARCHAR(100) | NOT NULL | New value after action |
| `user_id` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | User who performed action |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Creation timestamp |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true, INDEX | False if overridden by explicit label |
| `label_metadata` | JSONB | NULLABLE | Additional action metadata |

**Indexes:**
- `ix_implicit_labels_vulnerability_id` on `vulnerability_id`
- `ix_implicit_labels_label` on `label`
- `ix_implicit_labels_source` on `source`
- `ix_implicit_labels_is_active` on `is_active`
- `ix_implicit_labels_created_at` on `created_at`
- `ix_implicit_labels_vuln_active` on `(vulnerability_id, is_active)` composite

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, SET NULL on delete)

**Label Mapping from Status Changes:**

| Status | Label | Confidence | Rationale |
|--------|-------|------------|-----------|
| `fixed` | `confirmed` | 0.95 | User fixed it = was real |
| `false_positive` | `false_positive` | 0.90 | Explicit FP marking |
| `wont_fix` | `wont_fix` | 0.80 | Real but accepted risk |
| `acknowledged` | `confirmed` | 0.60 | Lower confidence confirmation |

**Integration with ML Training:**
- Implicit labels are collected by `LabelAggregator`
- Explicit labels take priority over implicit labels
- `is_active=false` when overridden by explicit annotation

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

**Document Version:** 1.8.0
**Last Updated:** February 4, 2026 (Added deduplication audit fixes - Migration 066)
**Maintained By:** Apogee Team

---

## Recent Schema Changes

### Migration 066: Deduplication Audit Fixes (February 4, 2026)
- Added indexes for improved query performance on classification/deduplication columns:
  - `ix_vulnerabilities_classification_confidence`
  - `ix_vulnerabilities_classification_method`
  - `ix_vulnerabilities_deduplication_strategy`
  - `ix_vulnerabilities_similarity_score`
- Fixed `canonical_finding_id` FK in deduplication_groups: changed from CASCADE to SET NULL
  - Preserves deduplication groups when canonical finding is deleted
  - Prevents loss of audit history and group membership data

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

- **Implementation Summary**: `/Users/pwner/Git/ABS/TaskDocs-Apogee/blocksecops/implementation-summaries/PHASE-4D-IMPLEMENTATION-COMPLETE.md`
- **Model Fixes**: `/Users/pwner/Git/ABS/TaskDocs-Apogee/blocksecops/03-phase-4-intelligence/PHASE-4D-MODEL-FIXES-COMPLETE.md`
- **Parser Fixes**: `/Users/pwner/Git/ABS/TaskDocs-Apogee/blocksecops/03-phase-4-intelligence/PHASE-4D-PARSER-CLASSIFICATION-FIX-COMPLETE.md`
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
- **Task Documentation**: `/TaskDocs-Apogee/phases/05-phase-5-ai-ml/`
- **ML Development Standards**: `/docs/standards/ml-development.md`
- **Feature Tests**: `/docs/feature-tests/27-ai-ml-features.md`

---

## Phase 6 Summary: Unified Integrations Hub (January 2026)

**Phase 6: Unified Integrations Hub** was completed on January 23, 2026.

### New Tables

#### `ide_tokens`

IDE integration tokens for VS Code and IntelliJ extensions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique token identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE | Owner user |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE CASCADE | Associated organization |
| `name` | VARCHAR(255) | NOT NULL | Display name (e.g., "My Laptop - VS Code") |
| `ide_type` | VARCHAR(50) | NOT NULL | 'vscode' or 'intellij' |
| `token_prefix` | VARCHAR(12) | NOT NULL, INDEX | First 12 chars for display |
| `token_hash` | VARCHAR(64) | NOT NULL | SHA-256 hash of full token |
| `permissions` | JSONB | NOT NULL, DEFAULT '[]' | List of granted permissions |
| `last_used_at` | TIMESTAMPTZ | NULLABLE | Last API call timestamp |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true | Active status |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |

**Indexes:**
- `ix_ide_tokens_user_id` on `user_id`
- `ix_ide_tokens_token_prefix` on `token_prefix`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)

---

#### `service_accounts`

Organization-level service accounts for CI/CD automation (Growth tier+, Admin only).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique account identifier |
| `organization_id` | UUID | NOT NULL, FK → organizations.id ON DELETE CASCADE, INDEX | Owner organization |
| `name` | VARCHAR(255) | NOT NULL | Display name (e.g., "GitHub Actions Bot") |
| `description` | VARCHAR(500) | NULLABLE | Usage description |
| `created_by` | UUID | NOT NULL, FK → users.id ON DELETE RESTRICT | Admin who created |
| `key_prefix` | VARCHAR(12) | NOT NULL, INDEX | First 12 chars (bso_sa_xxxx) |
| `key_hash` | VARCHAR(64) | NOT NULL | SHA-256 hash of full key |
| `scopes` | JSONB | NOT NULL, DEFAULT '[]' | List of granted permissions |
| `rate_limit_per_minute` | INTEGER | NOT NULL, DEFAULT 120 | Rate limit per minute |
| `rate_limit_per_hour` | INTEGER | NOT NULL, DEFAULT 2000 | Rate limit per hour |
| `last_used_at` | TIMESTAMPTZ | NULLABLE | Last API call timestamp |
| `total_requests` | INTEGER | NOT NULL, DEFAULT 0 | Lifetime request count |
| `expires_at` | TIMESTAMPTZ | NULLABLE | Optional expiration |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true, INDEX | Active status |
| `revoked_at` | TIMESTAMPTZ | NULLABLE | When revoked |
| `revoked_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | Admin who revoked |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `idx_service_accounts_org_id` on `organization_id`
- `idx_service_accounts_key_prefix` on `key_prefix`
- `idx_service_accounts_is_active` on `is_active`

**Relationships:**
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)
- Many-to-one with `users` (created_by, RESTRICT DELETE)
- Many-to-one with `users` (revoked_by, SET NULL)

**Constraints:**
- Maximum 20 active service accounts per organization
- Key prefix must start with 'bso_sa_'

**Service Account Scopes:**
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

### Related Documentation

- **Feature Test**: `docs/feature-tests/45-integrations-hub.md`
- **Task Documentation**: `TaskDocs-Apogee/DOCUMENTATION-UPDATE-2026-01-23-INTEGRATIONS-HUB.md`
- **User Documentation**: `blocksecops-docs/integrations/hub/README.md`

---

## ML Data Strategy & Legal Compliance (January 2026)

**ML Data Strategy** was completed on January 30, 2026 to support GDPR/LGPD compliance for ML data collection.

### New Tables

#### `tos_consent_records`

Tracks user consent for Terms of Service and Privacy Policy with version history for GDPR/LGPD compliance.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique consent identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | User who consented |
| `tos_version` | VARCHAR(20) | NOT NULL | Terms of Service version accepted |
| `privacy_policy_version` | VARCHAR(20) | NOT NULL | Privacy Policy version accepted |
| `ml_data_collection_consent` | BOOLEAN | NOT NULL, DEFAULT true | Consent for ML data collection |
| `consent_ip_address` | VARCHAR(45) | NULLABLE | IP address at time of consent |
| `consent_user_agent` | TEXT | NULLABLE | User agent string at consent |
| `consented_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | When consent was given |
| `withdrawn_at` | TIMESTAMPTZ | NULLABLE | When consent was withdrawn |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Record creation timestamp |

**Indexes:**
- `ix_tos_consent_records_user_id` on `user_id`
- `ix_tos_consent_records_consented_at` on `consented_at`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)

---

#### `ml_training_data_provenance`

Tracks data lineage for ML training data with consent references and exclusion tracking.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique provenance identifier |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE, INDEX | Labeled vulnerability |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE SET NULL, INDEX | Organization context |
| `user_id` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL, INDEX | User who labeled |
| `label` | VARCHAR(50) | NOT NULL | true_positive, false_positive, needs_review |
| `confidence` | FLOAT | NULLABLE | Label confidence 0.0-1.0 |
| `features_snapshot` | JSONB | NULLABLE | Anonymized feature data (no PII) |
| `tos_consent_id` | UUID | NULLABLE, FK → tos_consent_records.id ON DELETE SET NULL | Consent reference |
| `consent_version` | VARCHAR(20) | NULLABLE | ToS version at labeling time |
| `excluded_from_training` | BOOLEAN | NOT NULL, DEFAULT false, INDEX | Excluded from ML training |
| `exclusion_reason` | VARCHAR(100) | NULLABLE | user_consent_withdrawn, organization_opted_out |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_ml_provenance_vulnerability_id` on `vulnerability_id`
- `ix_ml_provenance_organization_id` on `organization_id`
- `ix_ml_provenance_user_id` on `user_id`
- `ix_ml_provenance_excluded` on `excluded_from_training`
- `ix_ml_provenance_created_at` on `created_at`

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)
- Many-to-one with `organizations` (organization_id, SET NULL)
- Many-to-one with `users` (user_id, SET NULL)
- Many-to-one with `tos_consent_records` (tos_consent_id, SET NULL)

---

#### `gdpr_data_requests`

Tracks GDPR Article 15 (access) and Article 17 (erasure) data requests.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique request identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Requesting user |
| `request_type` | VARCHAR(20) | NOT NULL, INDEX | export, deletion |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'pending', INDEX | pending, processing, completed, rejected |
| `requester_email` | VARCHAR(255) | NOT NULL | Email for notification |
| `requested_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Request timestamp |
| `processed_at` | TIMESTAMPTZ | NULLABLE | Processing completion timestamp |
| `processed_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | Admin who processed |
| `export_file_path` | VARCHAR(500) | NULLABLE | Path to export file |
| `export_expires_at` | TIMESTAMPTZ | NULLABLE | Export download expiry |
| `notes` | TEXT | NULLABLE | Admin notes |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Record creation timestamp |

**Indexes:**
- `ix_gdpr_requests_user_id` on `user_id`
- `ix_gdpr_requests_status` on `status`
- `ix_gdpr_requests_request_type` on `request_type`
- `ix_gdpr_requests_requested_at` on `requested_at`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `users` (processed_by, SET NULL)

---

### Organization AI Opt-Out Columns

Columns added to `organizations` table for Enterprise AI opt-out:

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `ai_data_collection_disabled` | BOOLEAN | NOT NULL, DEFAULT false | Enterprise AI opt-out flag |
| `ai_opt_out_date` | TIMESTAMPTZ | NULLABLE | When opt-out was enabled |
| `ai_opt_out_reason` | VARCHAR(500) | NULLABLE | Reason for opt-out |

**Note:** AI opt-out is only available for Enterprise tier organizations and must be set by organization admin via API request.

### Related Documentation

- **Feature Test**: `docs/feature-tests/48-ml-data-strategy.md`
- **Task Documentation**: `TaskDocs-Apogee/DOCUMENTATION-UPDATE-2026-01-30-ML-DATA-STRATEGY.md`
- **Database Migrations**: `docs/database/MIGRATIONS.md` (Migrations 053-055)

---

## Phase 4.5: OAuth Integration Credentials (February 2026)

**Phase 4.5: Third-Party Integrations** added OAuth credential storage for GitHub, GitLab, Bitbucket, JIRA, and Jenkins connections.

### New Tables

#### `integrations`

Third-party integration connections storing OAuth state and provider metadata.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique integration identifier |
| `organization_id` | UUID | NOT NULL, FK → organizations.id ON DELETE CASCADE, INDEX | Owner organization |
| `provider` | VARCHAR(50) | NOT NULL, INDEX | `github`, `gitlab`, `bitbucket`, `jira`, `jenkins` |
| `name` | VARCHAR(255) | NOT NULL | Display name |
| `status` | VARCHAR(50) | NOT NULL, DEFAULT 'pending', INDEX | `pending`, `connected`, `expired`, `error` |
| `external_account_id` | VARCHAR(255) | NULLABLE | Provider user/account ID |
| `external_username` | VARCHAR(255) | NULLABLE | Provider username |
| `external_avatar_url` | VARCHAR(2048) | NULLABLE | Provider avatar URL |
| `jira_cloud_id` | VARCHAR(255) | NULLABLE | JIRA cloud instance ID |
| `jira_site_url` | VARCHAR(2048) | NULLABLE | JIRA site URL |
| `settings` | JSONB | NULLABLE, DEFAULT '{}' | Provider-specific settings |
| `repos_synced` | INTEGER | NOT NULL, DEFAULT 0 | Count of synced repositories |
| `last_sync_at` | TIMESTAMPTZ | NULLABLE | Last repository sync |
| `last_error` | TEXT | NULLABLE | Last error message (sanitized, no internal details) |
| `created_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL, INDEX | User who created |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_integrations_org_provider_unique` UNIQUE on (`organization_id`, `provider`)
- `ix_integrations_organization_id` on `organization_id`
- `ix_integrations_provider` on `provider`
- `ix_integrations_status` on `status`
- `ix_integrations_created_by` on `created_by`

**Relationships:**
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)
- Many-to-one with `users` (created_by, SET NULL)
- One-to-one with `integration_credentials` (CASCADE DELETE)
- One-to-many with `integration_repositories` (CASCADE DELETE)
- One-to-many with `jira_project_mappings` (CASCADE DELETE)

---

#### `integration_credentials`

Encrypted OAuth tokens for integration connections. Access and refresh tokens are encrypted with Fernet (AES-128-CBC + HMAC-SHA256) before storage.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique credential identifier |
| `integration_id` | UUID | NOT NULL, UNIQUE, FK → integrations.id ON DELETE CASCADE, INDEX | Parent integration |
| `access_token_encrypted` | TEXT | NOT NULL | Fernet-encrypted access token |
| `refresh_token_encrypted` | TEXT | NULLABLE | Fernet-encrypted refresh token |
| `token_type` | VARCHAR(50) | NOT NULL, DEFAULT 'Bearer' | OAuth token type |
| `scopes` | JSONB | NULLABLE | List of granted OAuth scopes |
| `expires_at` | TIMESTAMPTZ | NULLABLE | Token expiry time (UTC) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_integration_credentials_integration_id` UNIQUE on `integration_id`

**Relationships:**
- One-to-one with `integrations` (integration_id, CASCADE DELETE)

**Security Notes:**
- Tokens encrypted with `INTEGRATION_ENCRYPTION_KEY` (Fernet, base64-encoded 32-byte key)
- Encryption is **mandatory in production** — API service refuses to start without key
- Encrypted values prefixed with `gAAAAA` (Fernet format)
- Error messages stored in `integrations.last_error` are sanitized via `get_safe_error_detail()`

### Related Documentation

- **Feature Test**: `docs/feature-tests/76-oauth-audit-hardening.md`
- **Pipeline**: `docs/pipelines/oauth-integration-pipeline.md`
- **Workflow**: `docs/workflows/oauth-integration-workflow.md`
- **Playbook**: `docs/playbooks/oauth-provider-setup.md`

---

---

## AI Copilot (February 2026)

The AI Copilot feature provides conversational security analysis with repair suggestions and code review assistance.

### New Tables

#### `copilot_conversations`

Stores AI Copilot conversation sessions, optionally scoped to a specific scan or project.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique conversation identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Owner user |
| `scan_id` | UUID | NULLABLE, FK → scans.id ON DELETE SET NULL, INDEX | Associated scan context |
| `project_id` | UUID | NULLABLE, FK → projects.id ON DELETE SET NULL, INDEX | Associated project context |
| `title` | VARCHAR(255) | NOT NULL | Conversation display title |
| `summary` | TEXT | NULLABLE | Optional conversation summary |
| `is_archived` | BOOLEAN | NOT NULL, DEFAULT false | Archived status |
| `message_count` | INTEGER | NOT NULL, DEFAULT 0 | Total messages in conversation |
| `total_tokens` | INTEGER | NOT NULL, DEFAULT 0 | Cumulative token usage |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_copilot_conversations_user_id` on `user_id`
- `ix_copilot_conversations_scan_id` on `scan_id`
- `ix_copilot_conversations_project_id` on `project_id`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `scans` (scan_id, SET NULL)
- Many-to-one with `projects` (project_id, SET NULL)
- One-to-many with `copilot_messages` (CASCADE DELETE)

---

#### `copilot_messages`

Individual messages within a Copilot conversation including token usage and optional user ratings.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique message identifier |
| `conversation_id` | UUID | NOT NULL, FK → copilot_conversations.id ON DELETE CASCADE, INDEX | Parent conversation |
| `role` | VARCHAR(20) | NOT NULL | `user` or `assistant` |
| `content` | TEXT | NOT NULL | Message text content |
| `context_sources` | JSONB | NULLABLE | Sources used for context (scan IDs, vulnerability IDs, etc.) |
| `tokens_input` | INTEGER | NOT NULL, DEFAULT 0 | Input tokens consumed |
| `tokens_output` | INTEGER | NOT NULL, DEFAULT 0 | Output tokens generated |
| `model_used` | VARCHAR(100) | NULLABLE | Model identifier (e.g., claude-sonnet-4-6) |
| `generation_time_ms` | INTEGER | NULLABLE | Response generation time in milliseconds |
| `rating` | INTEGER | NULLABLE | User rating 1-5 |
| `feedback_text` | TEXT | NULLABLE | Optional written feedback |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Message timestamp |

**Indexes:**
- `ix_copilot_messages_conversation_id` on `conversation_id`

**Relationships:**
- Many-to-one with `copilot_conversations` (conversation_id, CASCADE DELETE)

---

#### `repair_suggestions`

AI-generated code repair suggestions for vulnerabilities including the diff patch and application tracking.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique suggestion identifier |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE, INDEX | Target vulnerability |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Requesting user |
| `original_code` | TEXT | NOT NULL | Original vulnerable code snippet |
| `file_path` | VARCHAR(500) | NULLABLE | Source file path |
| `start_line` | INTEGER | NULLABLE | Start line of the affected code |
| `end_line` | INTEGER | NULLABLE | End line of the affected code |
| `fixed_code` | TEXT | NOT NULL | Repaired code snippet |
| `diff_patch` | TEXT | NOT NULL | Unified diff patch |
| `explanation` | TEXT | NOT NULL | Human-readable explanation of the fix |
| `fix_type` | VARCHAR(50) | NOT NULL | Category of fix (e.g., input_validation, access_control) |
| `confidence` | FLOAT | NOT NULL, DEFAULT 0.0 | Model confidence 0.0-1.0 |
| `model_used` | VARCHAR(100) | NOT NULL | Model identifier |
| `tokens_input` | INTEGER | NOT NULL, DEFAULT 0 | Input tokens consumed |
| `tokens_output` | INTEGER | NOT NULL, DEFAULT 0 | Output tokens generated |
| `generation_time_ms` | INTEGER | NULLABLE | Generation time in milliseconds |
| `was_applied` | BOOLEAN | NOT NULL, DEFAULT false | Whether fix was applied |
| `applied_at` | TIMESTAMPTZ | NULLABLE | When fix was applied |
| `rating` | INTEGER | NULLABLE | User rating 1-5 |
| `feedback_text` | TEXT | NULLABLE | Optional written feedback |
| `was_helpful` | BOOLEAN | NULLABLE | User helpful flag |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_repair_suggestions_vulnerability_id` on `vulnerability_id`
- `ix_repair_suggestions_user_id` on `user_id`

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, CASCADE DELETE)

---

#### `review_suggestions`

AI-generated narrative review suggestions for vulnerabilities including risk explanation and recommended fixes.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique suggestion identifier |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE, INDEX | Target vulnerability |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Requesting user |
| `suggestion_text` | TEXT | NOT NULL | Main suggestion narrative |
| `risk_explanation` | TEXT | NULLABLE | Risk explanation text |
| `attack_scenario` | TEXT | NULLABLE | Attack scenario description |
| `recommended_fix` | TEXT | NULLABLE | Recommended remediation |
| `code_context` | TEXT | NULLABLE | Relevant code context |
| `model_used` | VARCHAR(100) | NOT NULL | Model identifier |
| `tokens_input` | INTEGER | NOT NULL, DEFAULT 0 | Input tokens consumed |
| `tokens_output` | INTEGER | NOT NULL, DEFAULT 0 | Output tokens generated |
| `generation_time_ms` | INTEGER | NULLABLE | Generation time in milliseconds |
| `is_cached` | BOOLEAN | NOT NULL, DEFAULT false | Whether response was served from cache |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |

**Indexes:**
- `idx_review_suggestions_vulnerability_id` on `vulnerability_id`
- `idx_review_suggestions_user_id` on `user_id`
- `idx_review_suggestions_created_at` on `created_at`

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, CASCADE DELETE)
- One-to-many with `review_feedback` (CASCADE DELETE)

---

#### `review_feedback`

User feedback on AI review suggestions including multi-dimensional quality ratings.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique feedback identifier |
| `suggestion_id` | UUID | NOT NULL, FK → review_suggestions.id ON DELETE CASCADE, INDEX | Parent suggestion |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Feedback author |
| `rating` | INTEGER | NOT NULL, INDEX | Overall rating 1-5 |
| `was_helpful` | BOOLEAN | NOT NULL | Whether suggestion was helpful |
| `was_applied` | BOOLEAN | NULLABLE | Whether suggestion was applied |
| `feedback_text` | TEXT | NULLABLE | Optional written feedback |
| `accuracy_rating` | INTEGER | NULLABLE | Accuracy sub-rating 1-5 |
| `clarity_rating` | INTEGER | NULLABLE | Clarity sub-rating 1-5 |
| `usefulness_rating` | INTEGER | NULLABLE | Usefulness sub-rating 1-5 |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Feedback timestamp |

**Indexes:**
- `idx_review_feedback_suggestion_id` on `suggestion_id`
- `idx_review_feedback_user_id` on `user_id`
- `idx_review_feedback_rating` on `rating`

**Relationships:**
- Many-to-one with `review_suggestions` (suggestion_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, CASCADE DELETE)

---

## ML/Training Pipeline (February 2026)

Tables supporting the ML active learning pipeline, weak supervision, and scanner quality measurement.

### New Tables

#### `active_learning_queue`

Vulnerability samples queued for active learning label collection, prioritized by model uncertainty.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique queue entry identifier |
| `vulnerability_id` | UUID | NOT NULL, UNIQUE, FK → vulnerabilities.id ON DELETE CASCADE | Target vulnerability (one entry per vulnerability) |
| `uncertainty_score` | FLOAT | NOT NULL | Model uncertainty (higher = more valuable to label) |
| `prediction` | FLOAT | NOT NULL | Current model prediction 0.0-1.0 |
| `priority` | INTEGER | NOT NULL | Queue priority (lower number = higher priority) |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'pending' | `pending`, `shown`, `labeled`, `skipped` |
| `shown_to_user_id` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | User who reviewed this entry |
| `shown_at` | TIMESTAMPTZ | NULLABLE | When entry was shown to user |
| `labeled_at` | TIMESTAMPTZ | NULLABLE | When user submitted label |
| `label_result` | VARCHAR(20) | NULLABLE | Label submitted by user |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Entry creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `active_learning_queue_vulnerability_id_key` UNIQUE on `vulnerability_id`
- `idx_alq_priority_pending` on `priority` WHERE status = 'pending'
- `idx_alq_status` on `status`

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)
- Many-to-one with `users` (shown_to_user_id, SET NULL)

---

#### `weak_labels`

Programmatically assigned labels from heuristic sources used in weak supervision for ML training.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique weak label identifier |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE, INDEX | Labeled vulnerability |
| `label` | VARCHAR(20) | NOT NULL | `true_positive`, `false_positive`, `needs_review` |
| `confidence` | FLOAT | NOT NULL | Label confidence 0.0-1.0 |
| `source` | VARCHAR(20) | NOT NULL | Labeling function source (e.g., `heuristic`, `scanner`, `pattern`) |
| `sample_weight` | FLOAT | NULLABLE | Training sample weight override |
| `metadata` | JSONB | NULLABLE | Source-specific metadata |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true | Whether label is current |
| `superseded_by` | UUID | NULLABLE | ID of replacement weak label |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Label creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `idx_weak_labels_vuln_id` on `vulnerability_id`
- `idx_weak_labels_unique_active` UNIQUE on (`vulnerability_id`, `source`) WHERE is_active = true
- `idx_weak_labels_source_active` on `source` WHERE is_active = true

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)

---

#### `scanner_quality_metrics`

Per-scanner accuracy and quality metrics calculated from user feedback and classification data.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | INTEGER | PRIMARY KEY, SERIAL | Auto-increment identifier |
| `scanner_id` | VARCHAR(50) | NOT NULL, UNIQUE | Scanner identifier (e.g., `slither`, `aderyn`) |
| `total_findings` | INTEGER | NOT NULL, DEFAULT 0 | Total findings attributed to scanner |
| `confirmed_count` | INTEGER | NOT NULL, DEFAULT 0 | Findings confirmed as true positives |
| `false_positive_count` | INTEGER | NOT NULL, DEFAULT 0 | Findings marked as false positives |
| `wont_fix_count` | INTEGER | NOT NULL, DEFAULT 0 | Findings marked as won't fix |
| `confirmation_rate` | FLOAT | NULLABLE | Calculated true positive rate |
| `false_positive_rate` | FLOAT | NULLABLE | Calculated false positive rate |
| `precision_score` | FLOAT | NULLABLE | Precision metric (TP / (TP + FP)) |
| `user_override_count` | INTEGER | NOT NULL, DEFAULT 0 | Number of user-overridden classifications |
| `avg_user_confidence` | FLOAT | NULLABLE | Average user confidence in labels |
| `user_preference_score` | FLOAT | NOT NULL, DEFAULT 0.5 | Composite user preference score |
| `calculated_priority` | INTEGER | NOT NULL, DEFAULT 50 | Scanner display priority (lower = higher priority) |
| `manual_priority_override` | INTEGER | NULLABLE | Admin-set priority override |
| `last_calculated_at` | TIMESTAMPTZ | NULLABLE | When metrics were last recalculated |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_scanner_quality_metrics_scanner_id` UNIQUE on `scanner_id`
- `ix_scanner_quality_metrics_calculated_priority` on `calculated_priority`

**Relationships:**
- Referenced by scanner attribution in `vulnerabilities` (scanner_id string reference, no FK)

---

#### `ml_training_data_provenance`

Tracks full data lineage for ML training records including consent, user identity, and exclusion status.

> **Note:** This table was partially documented in the ML Data Strategy section above. The schema below reflects the actual database columns as verified February 28, 2026.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique provenance identifier |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE, INDEX | Labeled vulnerability |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE SET NULL, INDEX | Organization context |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE SET NULL, INDEX | User who labeled |
| `label` | VARCHAR(20) | NOT NULL | Classification label |
| `confidence` | FLOAT | NULLABLE | Label confidence 0.0-1.0 |
| `features_snapshot` | JSONB | NOT NULL | Anonymized feature data at labeling time |
| `tos_consent_id` | UUID | NULLABLE, FK → tos_consent_records.id ON DELETE SET NULL | Consent record reference |
| `consent_version` | VARCHAR(20) | NOT NULL | ToS version at labeling time |
| `excluded_from_training` | BOOLEAN | NOT NULL, DEFAULT false, INDEX | Excluded from training pipeline |
| `exclusion_reason` | VARCHAR(50) | NULLABLE | Reason for exclusion |
| `collected_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Data collection timestamp |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Record creation timestamp |

**Indexes:**
- `ix_ml_training_data_provenance_vulnerability_id` on `vulnerability_id`
- `ix_ml_training_data_provenance_organization_id` on `organization_id`
- `ix_ml_training_data_provenance_user_id` on `user_id`
- `ix_ml_training_data_provenance_excluded_from_training` on `excluded_from_training`

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)
- Many-to-one with `organizations` (organization_id, SET NULL)
- Many-to-one with `users` (user_id, SET NULL)
- Many-to-one with `tos_consent_records` (tos_consent_id, SET NULL)

---

## Intelligence Enrichment (February 2026)

Tables providing vulnerability intelligence enrichment from CVE databases, real-world exploit data, and trend analytics.

### New Tables

#### `cves`

CVE (Common Vulnerabilities and Exposures) records enriched with blockchain-specific metadata and vector embeddings for semantic search.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique CVE record identifier |
| `cve_id` | VARCHAR(20) | NOT NULL, UNIQUE, INDEX | CVE identifier (e.g., CVE-2023-12345) |
| `cwe_id` | VARCHAR(20) | NULLABLE, INDEX | CWE identifier (e.g., CWE-89) |
| `severity` | VARCHAR(20) | NOT NULL, INDEX | `critical`, `high`, `medium`, `low`, `none` |
| `cvss_score` | FLOAT | NULLABLE | CVSS v3 base score |
| `cvss_vector` | VARCHAR(100) | NULLABLE | CVSS v3 vector string |
| `title` | VARCHAR(200) | NOT NULL | Short CVE title |
| `description` | TEXT | NOT NULL | Full CVE description |
| `remediation` | TEXT | NULLABLE | Remediation guidance |
| `affected_languages` | VARCHAR(20)[] | NOT NULL | Affected languages (e.g., ['solidity', 'rust']) |
| `affected_products` | VARCHAR(100)[] | NULLABLE | Affected products/frameworks |
| `vulnerability_type` | VARCHAR(100) | NULLABLE | Vulnerability category |
| `references` | JSONB | NULLABLE | External reference URLs |
| `pattern_ids` | VARCHAR(50)[] | NULLABLE | Related vulnerability pattern IDs |
| `published_at` | TIMESTAMPTZ | NULLABLE | NVD publication date |
| `modified_at` | TIMESTAMPTZ | NULLABLE | Last modification date |
| `embedding` | vector(1536) | NULLABLE | Semantic embedding for similarity search |
| `source` | VARCHAR(50) | NOT NULL, DEFAULT 'nvd' | Data source (`nvd`, `osv`, `manual`) |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `cves_cve_id_key` UNIQUE on `cve_id`
- `ix_cves_cve_id` on `cve_id`
- `ix_cves_cwe_id` on `cwe_id`
- `ix_cves_severity` on `severity`

**Relationships:**
- Referenced by vulnerability intelligence linking (pattern_ids array, no FK constraint)

---

#### `exploits`

Real-world DeFi and smart contract exploit records for intelligence enrichment and risk scoring.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique exploit identifier |
| `source` | VARCHAR(50) | NOT NULL | Data source (`rekt`, `immunefi`, `manual`) |
| `source_id` | VARCHAR(100) | NULLABLE | Source-specific record ID |
| `source_url` | TEXT | NULLABLE | Source reference URL |
| `protocol` | VARCHAR(100) | NOT NULL, INDEX | Protocol name (e.g., `Uniswap`, `Curve`) |
| `chain` | VARCHAR(50) | NOT NULL, INDEX | Blockchain (e.g., `ethereum`, `bsc`) |
| `contract_addresses` | VARCHAR(42)[] | NULLABLE | Exploited contract addresses |
| `date` | TIMESTAMPTZ | NOT NULL, INDEX | Date of exploit |
| `loss_usd` | NUMERIC(20,2) | NULLABLE | Total loss in USD |
| `funds_recovered` | NUMERIC(20,2) | NULLABLE | Recovered funds in USD |
| `attack_vector` | VARCHAR(100) | NOT NULL, INDEX | Attack vector (e.g., `flash_loan`, `reentrancy`) |
| `root_cause` | VARCHAR(200) | NULLABLE | Root cause description |
| `vulnerability_types` | VARCHAR(50)[] | NULLABLE | Vulnerability type tags |
| `title` | VARCHAR(200) | NOT NULL | Exploit title |
| `description` | TEXT | NOT NULL | Detailed description |
| `technical_analysis` | TEXT | NULLABLE | Technical breakdown |
| `code_snippet` | TEXT | NULLABLE | Relevant code snippet |
| `tx_hashes` | VARCHAR(66)[] | NULLABLE | Transaction hashes |
| `embedding` | vector(1536) | NULLABLE | Semantic embedding for similarity search |
| `is_verified` | BOOLEAN | NOT NULL, DEFAULT false | Whether record has been verified |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_exploits_protocol` on `protocol`
- `ix_exploits_chain` on `chain`
- `ix_exploits_date` on `date`
- `ix_exploits_attack_vector` on `attack_vector`

**Relationships:**
- Referenced by vulnerability intelligence enrichment (no FK — external data)

---

#### `poc_exploits`

AI-generated proof-of-concept exploit code for confirmed vulnerabilities. Safety-validated before storage.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique PoC identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Requesting user |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE, INDEX | Target vulnerability |
| `exploit_code` | TEXT | NOT NULL | Generated exploit code |
| `setup_code` | TEXT | NULLABLE | Test environment setup code |
| `test_code` | TEXT | NULLABLE | Test runner code |
| `explanation` | TEXT | NULLABLE | Explanation of how exploit works |
| `attack_vector` | VARCHAR(100) | NULLABLE | Attack vector used |
| `preconditions` | TEXT | NULLABLE | Required preconditions |
| `impact_assessment` | TEXT | NULLABLE | Impact of successful exploit |
| `contract_code` | TEXT | NULLABLE | Vulnerable contract code context |
| `vulnerability_description` | TEXT | NULLABLE | Vulnerability description at generation time |
| `model_used` | VARCHAR(100) | NOT NULL | Model identifier |
| `tokens_input` | INTEGER | NOT NULL | Input tokens consumed |
| `tokens_output` | INTEGER | NOT NULL | Output tokens generated |
| `generation_time_ms` | INTEGER | NULLABLE | Generation time in milliseconds |
| `confidence` | FLOAT | NOT NULL | Model confidence 0.0-1.0 |
| `safety_validated` | BOOLEAN | NOT NULL | Whether safety check passed |
| `safety_warnings` | JSON | NULLABLE | Safety check warnings |
| `disclaimer_included` | BOOLEAN | NOT NULL | Whether disclaimer was included in output |
| `rating` | INTEGER | NULLABLE | User rating 1-5 |
| `feedback_text` | TEXT | NULLABLE | Optional written feedback |
| `was_helpful` | BOOLEAN | NULLABLE | User helpful flag |
| `was_accurate` | BOOLEAN | NULLABLE | User accuracy flag |
| `created_at` | TIMESTAMPTZ | NOT NULL | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL | Last update timestamp |

**Indexes:**
- `ix_poc_exploits_vulnerability_id` on `vulnerability_id`
- `ix_poc_exploits_user_id` on `user_id`
- `ix_poc_exploits_created_at` on `created_at`

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, CASCADE DELETE)

---

#### `vulnerability_classifications`

4-class vulnerability classification records tracking confirmed, false_positive, wont_fix, and needs_review decisions with full history.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique classification identifier |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE, INDEX | Classified vulnerability |
| `user_id` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL, INDEX | User who classified (NULL = system) |
| `classification` | VARCHAR(20) | NOT NULL, INDEX | `confirmed`, `false_positive`, `wont_fix`, `needs_review` |
| `previous_classification` | VARCHAR(20) | NULLABLE | Prior classification for audit trail |
| `confidence` | FLOAT | NULLABLE | Classifier confidence 0.0-1.0 |
| `feedback_text` | TEXT | NULLABLE | Rationale for classification |
| `tags` | VARCHAR(50)[] | NULLABLE, GIN INDEX | Classification tags |
| `fix_status` | VARCHAR(20) | NULLABLE, INDEX | `open`, `in_progress`, `fixed`, `verified` |
| `fix_commit_hash` | VARCHAR(64) | NULLABLE | Git commit hash of fix |
| `fix_verified` | BOOLEAN | NOT NULL, DEFAULT false | Whether fix has been verified |
| `fix_verified_at` | TIMESTAMPTZ | NULLABLE | Fix verification timestamp |
| `was_actually_vulnerable` | BOOLEAN | NULLABLE | Post-fix ground truth |
| `exploitability_score` | FLOAT | NULLABLE | Exploitability assessment 0.0-1.0 |
| `business_impact` | VARCHAR(20) | NULLABLE | `low`, `medium`, `high`, `critical` |
| `is_latest` | BOOLEAN | NOT NULL, DEFAULT true, INDEX | Whether this is the current classification |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Classification timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_vuln_classifications_vuln_id` on `vulnerability_id`
- `ix_vuln_classifications_user_id` on `user_id`
- `ix_vuln_classifications_classification` on `classification`
- `ix_vuln_classifications_is_latest` on `is_latest`
- `ix_vuln_classifications_fix_status` on `fix_status`
- `ix_vuln_classifications_created_at` on `created_at`
- `ix_vuln_classifications_latest_lookup` on (`vulnerability_id`, `is_latest`, `created_at`)
- `ix_vuln_classifications_tags` GIN on `tags`

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, SET NULL)

---

#### `vulnerability_interactions`

Tracks user interactions with vulnerabilities for implicit labeling and engagement analytics.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique interaction identifier |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE, INDEX | Interacted vulnerability |
| `user_id` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL, INDEX | Interacting user (NULL = anonymous) |
| `interaction_type` | VARCHAR(30) | NOT NULL | `view`, `expand`, `copy_snippet`, `export`, `share`, `dismiss` |
| `duration_ms` | INTEGER | NULLABLE | Time spent on interaction in milliseconds |
| `metadata` | JSONB | NULLABLE | Interaction-specific metadata |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Interaction timestamp |

**Indexes:**
- `idx_vuln_interactions_vuln_id` on `vulnerability_id`
- `idx_vuln_interactions_user_id` on `user_id`
- `idx_vuln_interactions_created_at` on `created_at`

**Relationships:**
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, SET NULL)

---

#### `vulnerability_trends`

Aggregated vulnerability trend metrics per pattern/contract/user over configurable time periods for analytics dashboards.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique trend record identifier |
| `pattern_id` | VARCHAR(20) | NOT NULL, FK → vulnerability_patterns.id ON DELETE CASCADE, INDEX | Vulnerability pattern |
| `contract_id` | UUID | NULLABLE, FK → contracts.id ON DELETE CASCADE, INDEX | Optional contract scope |
| `user_id` | UUID | NULLABLE, FK → users.id ON DELETE CASCADE, INDEX | Optional user scope |
| `period_start` | TIMESTAMPTZ | NOT NULL, INDEX | Period start (inclusive) |
| `period_end` | TIMESTAMPTZ | NOT NULL, INDEX | Period end (exclusive) |
| `period_type` | VARCHAR(20) | NOT NULL, INDEX | `daily`, `weekly`, `monthly` |
| `total_occurrences` | INTEGER | NOT NULL, DEFAULT 0 | Total vulnerability occurrences |
| `unique_contracts` | INTEGER | NOT NULL, DEFAULT 0 | Unique contracts affected |
| `new_occurrences` | INTEGER | NOT NULL, DEFAULT 0 | New occurrences in period |
| `reintroduced_occurrences` | INTEGER | NOT NULL, DEFAULT 0 | Previously fixed then reintroduced |
| `critical_count` | INTEGER | NOT NULL, DEFAULT 0 | Critical severity count |
| `high_count` | INTEGER | NOT NULL, DEFAULT 0 | High severity count |
| `medium_count` | INTEGER | NOT NULL, DEFAULT 0 | Medium severity count |
| `low_count` | INTEGER | NOT NULL, DEFAULT 0 | Low severity count |
| `open_count` | INTEGER | NOT NULL, DEFAULT 0 | Open/unresolved count |
| `fixed_count` | INTEGER | NOT NULL, DEFAULT 0 | Fixed count |
| `false_positive_count` | INTEGER | NOT NULL, DEFAULT 0 | False positive count |
| `acknowledged_count` | INTEGER | NOT NULL, DEFAULT 0 | Acknowledged count |
| `scanner_distribution` | JSONB | NULLABLE | Breakdown by scanner |
| `avg_time_to_fix` | FLOAT | NULLABLE | Average days to fix |
| `fix_rate` | FLOAT | NULLABLE | Fix rate 0.0-1.0 |
| `reintroduction_rate` | FLOAT | NULLABLE | Reintroduction rate 0.0-1.0 |
| `avg_false_positive_score` | FLOAT | NULLABLE | Average FP confidence score |
| `avg_confidence` | FLOAT | NULLABLE | Average scanner confidence |
| `duplicate_rate` | FLOAT | NULLABLE | Deduplication rate 0.0-1.0 |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_vuln_trends_pattern_id` on `pattern_id`
- `ix_vuln_trends_contract_id` on `contract_id`
- `ix_vuln_trends_user_id` on `user_id`
- `ix_vuln_trends_period_start` on `period_start`
- `ix_vuln_trends_period_end` on `period_end`
- `ix_vuln_trends_period_type` on `period_type`
- `ix_vuln_trends_pattern_time_series` on (`pattern_id`, `period_type`, `period_start`)
- `ix_vuln_trends_contract_time_series` on (`contract_id`, `period_type`, `period_start`)
- `ix_vuln_trends_user_time_series` on (`user_id`, `period_type`, `period_start`)
- `uq_vuln_trends_pattern_contract_period` UNIQUE on (`pattern_id`, `contract_id`, `period_type`, `period_start`)

**Relationships:**
- Many-to-one with `vulnerability_patterns` (pattern_id, CASCADE DELETE)
- Many-to-one with `contracts` (contract_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, CASCADE DELETE)

---

## Contract Monitoring (February 2026)

On-chain contract monitoring with real-time alert detection for deployed smart contracts.

### New Tables

#### `monitored_contracts`

Deployed smart contracts registered for on-chain monitoring and alerting.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique monitored contract identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Owning user |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE SET NULL, INDEX | Owning organization |
| `address` | VARCHAR(42) | NOT NULL, INDEX | Contract address (0x-prefixed) |
| `chain` | VARCHAR(50) | NOT NULL, INDEX | Blockchain network (e.g., `ethereum`, `polygon`) |
| `name` | VARCHAR(200) | NULLABLE | Display name for contract |
| `abi` | JSONB | NULLABLE | Contract ABI for event decoding |
| `monitored_functions` | VARCHAR[] | NULLABLE | Functions to monitor (NULL = all) |
| `alert_threshold_usd` | NUMERIC(20,2) | NULLABLE | Alert threshold for value transfers (USD) |
| `is_active` | BOOLEAN | NOT NULL | Whether monitoring is active |
| `webhook_url` | TEXT | NULLABLE | Webhook URL for alert delivery |
| `webhook_secret` | VARCHAR(100) | NULLABLE | HMAC secret for webhook signature |
| `last_checked_block` | INTEGER | NULLABLE | Last blockchain block number checked |
| `created_at` | TIMESTAMPTZ | NOT NULL | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL | Last update timestamp |

**Indexes:**
- `ix_monitored_contracts_user_id` on `user_id`
- `ix_monitored_contracts_organization_id` on `organization_id`
- `ix_monitored_contracts_address` on `address`
- `ix_monitored_contracts_chain` on `chain`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `organizations` (organization_id, SET NULL)
- One-to-many with `alerts` (CASCADE DELETE)

---

#### `alerts`

Security alerts generated from on-chain event monitoring of registered contracts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique alert identifier |
| `contract_id` | UUID | NOT NULL, FK → monitored_contracts.id ON DELETE CASCADE, INDEX | Source monitored contract |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Alert owner |
| `alert_type` | VARCHAR(50) | NOT NULL, INDEX | Alert category (e.g., `large_transfer`, `unusual_access`) |
| `severity` | VARCHAR(20) | NOT NULL, INDEX | `critical`, `high`, `medium`, `low` |
| `title` | VARCHAR(500) | NOT NULL | Alert title |
| `description` | TEXT | NULLABLE | Detailed alert description |
| `tx_hash` | VARCHAR(66) | NULLABLE, INDEX | Triggering transaction hash |
| `block_number` | INTEGER | NULLABLE | Block number of triggering event |
| `from_address` | VARCHAR(42) | NULLABLE | Transaction sender address |
| `to_address` | VARCHAR(42) | NULLABLE | Transaction recipient address |
| `value_wei` | VARCHAR(78) | NULLABLE | Transfer value in wei |
| `value_usd` | NUMERIC(20,2) | NULLABLE | Transfer value in USD |
| `details` | JSONB | NULLABLE | Additional alert details |
| `function_called` | VARCHAR(200) | NULLABLE | Contract function that triggered alert |
| `acknowledged` | BOOLEAN | NOT NULL | Whether alert has been acknowledged |
| `acknowledged_at` | TIMESTAMPTZ | NULLABLE | Acknowledgment timestamp |
| `acknowledged_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | User who acknowledged |
| `webhook_sent` | BOOLEAN | NOT NULL | Whether webhook notification was sent |
| `webhook_sent_at` | TIMESTAMPTZ | NULLABLE | Webhook delivery timestamp |
| `detected_at` | TIMESTAMPTZ | NOT NULL, INDEX | When alert was detected |
| `created_at` | TIMESTAMPTZ | NOT NULL | Record creation timestamp |

**Indexes:**
- `ix_alerts_contract_id` on `contract_id`
- `ix_alerts_user_id` on `user_id`
- `ix_alerts_alert_type` on `alert_type`
- `ix_alerts_severity` on `severity`
- `ix_alerts_tx_hash` on `tx_hash`
- `ix_alerts_detected_at` on `detected_at`

**Relationships:**
- Many-to-one with `monitored_contracts` (contract_id, CASCADE DELETE)
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `users` (acknowledged_by, SET NULL)

---

## Contracts Metadata (February 2026)

User-defined tagging system for organizing and filtering contracts.

### New Tables

#### `contract_tags`

User-defined tags with color coding for contract organization.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique tag identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Tag owner |
| `name` | VARCHAR(50) | NOT NULL | Tag name |
| `color` | VARCHAR(7) | NOT NULL | Hex color code (e.g., `#FF5733`) |
| `description` | VARCHAR(255) | NULLABLE | Optional tag description |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_contract_tags_user_id` on `user_id`
- `ix_contract_tags_user_name` UNIQUE on (`user_id`, `name`)

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- One-to-many with `contract_tag_associations` (CASCADE DELETE)

---

#### `contract_tag_associations`

Join table linking contracts to user-defined tags.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique association identifier |
| `contract_id` | UUID | NOT NULL, FK → contracts.id ON DELETE CASCADE, INDEX | Tagged contract |
| `tag_id` | UUID | NOT NULL, FK → contract_tags.id ON DELETE CASCADE, INDEX | Applied tag |
| `assigned_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | When tag was applied |

**Indexes:**
- `ix_contract_tag_associations_contract_id` on `contract_id`
- `ix_contract_tag_associations_tag_id` on `tag_id`
- `ix_contract_tag_associations_unique` UNIQUE on (`contract_id`, `tag_id`)

**Relationships:**
- Many-to-one with `contracts` (contract_id, CASCADE DELETE)
- Many-to-one with `contract_tags` (tag_id, CASCADE DELETE)

---

## Invariant Generation (February 2026)

AI-generated formal verification invariants for smart contracts.

### New Tables

#### `invariants`

AI-generated invariant code for smart contracts, including application tracking and user feedback.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique invariant identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Requesting user |
| `contract_id` | UUID | NOT NULL, FK → contracts.id ON DELETE CASCADE, INDEX | Target contract |
| `invariant_code` | TEXT | NOT NULL | Generated invariant code |
| `invariant_type` | VARCHAR(50) | NOT NULL | `property`, `state`, `access_control`, `arithmetic` |
| `function_name` | VARCHAR(200) | NULLABLE | Specific function targeted |
| `description` | TEXT | NULLABLE | Human-readable description |
| `model_used` | VARCHAR(100) | NOT NULL | Model identifier |
| `tokens_input` | INTEGER | NOT NULL | Input tokens consumed |
| `tokens_output` | INTEGER | NOT NULL | Output tokens generated |
| `generation_time_ms` | INTEGER | NULLABLE | Generation time in milliseconds |
| `confidence` | FLOAT | NOT NULL | Model confidence 0.0-1.0 |
| `was_applied` | BOOLEAN | NOT NULL | Whether invariant was applied |
| `applied_at` | TIMESTAMPTZ | NULLABLE | Application timestamp |
| `rating` | INTEGER | NULLABLE | User rating 1-5 |
| `feedback_text` | TEXT | NULLABLE | Optional written feedback |
| `was_helpful` | BOOLEAN | NULLABLE | User helpful flag |
| `syntax_valid` | BOOLEAN | NULLABLE | Whether invariant passed syntax validation |
| `validation_error` | TEXT | NULLABLE | Syntax validation error message |
| `created_at` | TIMESTAMPTZ | NOT NULL | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL | Last update timestamp |

**Indexes:**
- `ix_invariants_user_id` on `user_id`
- `ix_invariants_contract_id` on `contract_id`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `contracts` (contract_id, CASCADE DELETE)

---

#### `invariant_templates`

Reusable invariant templates categorized by type for common security properties.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY | Unique template identifier |
| `name` | VARCHAR(200) | NOT NULL, UNIQUE | Template name |
| `description` | TEXT | NULLABLE | Template description |
| `template_code` | TEXT | NOT NULL | Template invariant code with placeholders |
| `invariant_type` | VARCHAR(50) | NOT NULL | `property`, `state`, `access_control`, `arithmetic` |
| `applicable_patterns` | JSON | NULLABLE | Vulnerability pattern IDs this template applies to |
| `keywords` | JSON | NULLABLE | Keywords for template search and matching |
| `usage_count` | INTEGER | NOT NULL | Number of times template has been used |
| `is_active` | BOOLEAN | NOT NULL | Whether template is available for use |
| `created_at` | TIMESTAMPTZ | NOT NULL | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL | Last update timestamp |

**Indexes:**
- `invariant_templates_name_key` UNIQUE on `name`

**Relationships:**
- Referenced by `invariants` generation (no FK — templates are seed data)

---

## Auth/Billing Extensions (February 2026)

Additional authentication, billing, and access management tables.

### New Tables

#### `service_accounts`

Organization-scoped service accounts for programmatic API access with granular scope control.

> **Note:** The `service_accounts` table was previously partially documented in the Integrations Hub section. The schema below reflects the actual database columns as verified February 28, 2026.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique service account identifier |
| `organization_id` | UUID | NOT NULL, FK → organizations.id ON DELETE CASCADE, INDEX | Owning organization |
| `name` | VARCHAR(255) | NOT NULL | Display name |
| `description` | VARCHAR(500) | NULLABLE | Optional description |
| `created_by` | UUID | NOT NULL, FK → users.id ON DELETE SET NULL, INDEX | Admin who created |
| `key_prefix` | VARCHAR(16) | NOT NULL, INDEX | First 16 characters of key (for lookup) |
| `key_hash` | VARCHAR(64) | NOT NULL | SHA-256 hash of full API key |
| `scopes` | JSONB | NOT NULL, DEFAULT '[]' | List of granted permission scopes |
| `rate_limit_per_minute` | INTEGER | NOT NULL, DEFAULT 120 | Rate limit per minute |
| `rate_limit_per_hour` | INTEGER | NOT NULL, DEFAULT 2000 | Rate limit per hour |
| `last_used_at` | TIMESTAMPTZ | NULLABLE | Last API call timestamp |
| `last_used_ip` | VARCHAR(45) | NULLABLE | IP of last API call |
| `total_requests` | INTEGER | NOT NULL, DEFAULT 0 | Lifetime request count |
| `expires_at` | TIMESTAMPTZ | NULLABLE | Optional expiration |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true, INDEX | Active status |
| `revoked_at` | TIMESTAMPTZ | NULLABLE | When revoked |
| `revoked_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | Admin who revoked |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_service_accounts_organization_id` on `organization_id`
- `ix_service_accounts_created_by` on `created_by`
- `ix_service_accounts_key_prefix` on `key_prefix`
- `ix_service_accounts_is_active` on `is_active`

**Relationships:**
- Many-to-one with `organizations` (organization_id, CASCADE DELETE)
- Many-to-one with `users` (created_by, SET NULL)
- Many-to-one with `users` (revoked_by, SET NULL)

---

#### `subscriptions`

Stripe subscription records tracking billing cycles, plan tiers, and cancellation state.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique subscription identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Subscriber user |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE SET NULL, INDEX | Organization scope (if applicable) |
| `stripe_subscription_id` | VARCHAR(255) | NOT NULL, UNIQUE | Stripe subscription ID (sub_xxx) |
| `stripe_customer_id` | VARCHAR(255) | NOT NULL, INDEX | Stripe customer ID (cus_xxx) |
| `stripe_price_id` | VARCHAR(255) | NULLABLE | Stripe price ID (price_xxx) |
| `plan_tier` | VARCHAR(50) | NOT NULL, INDEX | `developer`, `team`, `growth`, `enterprise` |
| `billing_interval` | VARCHAR(20) | NOT NULL | `monthly`, `annual` |
| `status` | VARCHAR(50) | NOT NULL, INDEX | `active`, `past_due`, `canceled`, `trialing` |
| `current_period_start` | TIMESTAMPTZ | NOT NULL | Current billing period start |
| `current_period_end` | TIMESTAMPTZ | NOT NULL | Current billing period end |
| `cancel_at_period_end` | BOOLEAN | NULLABLE, DEFAULT false | Schedule cancellation at period end |
| `canceled_at` | TIMESTAMPTZ | NULLABLE | Cancellation timestamp |
| `cancellation_reason` | VARCHAR(255) | NULLABLE | Reason for cancellation |
| `trial_start` | TIMESTAMPTZ | NULLABLE | Trial period start |
| `trial_end` | TIMESTAMPTZ | NULLABLE | Trial period end |
| `stripe_metadata` | JSONB | NULLABLE | Raw Stripe metadata |
| `created_at` | TIMESTAMPTZ | NULLABLE, DEFAULT now() | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE, DEFAULT now() | Last update timestamp |

**Indexes:**
- `subscriptions_stripe_subscription_id_key` UNIQUE on `stripe_subscription_id`
- `ix_subscriptions_user_id` on `user_id`
- `ix_subscriptions_organization_id` on `organization_id`
- `ix_subscriptions_stripe_customer_id` on `stripe_customer_id`
- `ix_subscriptions_plan_tier` on `plan_tier`
- `ix_subscriptions_status` on `status`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `organizations` (organization_id, SET NULL)

---

#### `billing_details`

Billing address and tax information for users, stored separately from payment processing data.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique billing record identifier |
| `user_id` | UUID | NOT NULL, UNIQUE, FK → users.id ON DELETE CASCADE, INDEX | Associated user (one per user) |
| `company_name` | VARCHAR(255) | NULLABLE | Company or organization name |
| `billing_email` | VARCHAR(255) | NULLABLE | Billing contact email |
| `address_line1` | VARCHAR(255) | NULLABLE | Street address line 1 |
| `address_line2` | VARCHAR(255) | NULLABLE | Street address line 2 |
| `city` | VARCHAR(100) | NULLABLE | City |
| `state` | VARCHAR(100) | NULLABLE | State or region |
| `postal_code` | VARCHAR(20) | NULLABLE | Postal or ZIP code |
| `country` | VARCHAR(2) | NULLABLE | ISO 3166-1 alpha-2 country code |
| `tax_id` | VARCHAR(100) | NULLABLE | Tax ID number |
| `tax_id_type` | VARCHAR(50) | NULLABLE | Tax ID type (e.g., `vat`, `ein`) |
| `tax_exempt` | BOOLEAN | NULLABLE, DEFAULT false | Tax exempt status |
| `created_at` | TIMESTAMPTZ | NULLABLE, DEFAULT now() | Record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NULLABLE, DEFAULT now() | Last update timestamp |

**Indexes:**
- `billing_details_user_id_key` UNIQUE on `user_id`
- `ix_billing_details_user_id` on `user_id`

**Relationships:**
- One-to-one with `users` (user_id, CASCADE DELETE)

---

#### `ide_tokens`

IDE plugin authentication tokens with fine-grained permission scopes for VS Code, JetBrains, and other IDE integrations.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique token identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Token owner |
| `organization_id` | UUID | NULLABLE, FK → organizations.id ON DELETE SET NULL, INDEX | Organization scope |
| `name` | VARCHAR(255) | NOT NULL | Display name for token |
| `ide_type` | VARCHAR(50) | NOT NULL, INDEX | `vscode`, `jetbrains`, `vim`, `emacs`, `other` |
| `token_prefix` | VARCHAR(16) | NOT NULL, INDEX | First 16 characters (for lookup without revealing full token) |
| `token_hash` | VARCHAR(64) | NOT NULL | SHA-256 hash of full token |
| `permissions` | JSONB | NOT NULL, DEFAULT '["scan:create","scan:read"]' | Granted permission scopes |
| `last_used_at` | TIMESTAMPTZ | NULLABLE | Last authentication timestamp |
| `last_used_ip` | VARCHAR(45) | NULLABLE | IP of last authentication |
| `total_scans` | INTEGER | NOT NULL, DEFAULT 0 | Total scans initiated via this token |
| `expires_at` | TIMESTAMPTZ | NULLABLE | Optional token expiry |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true, INDEX | Active status |
| `revoked_at` | TIMESTAMPTZ | NULLABLE | Revocation timestamp |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_ide_tokens_user_id` on `user_id`
- `ix_ide_tokens_organization_id` on `organization_id`
- `ix_ide_tokens_ide_type` on `ide_type`
- `ix_ide_tokens_token_prefix` on `token_prefix`
- `ix_ide_tokens_is_active` on `is_active`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- Many-to-one with `organizations` (organization_id, SET NULL)

---

#### `support_impersonation_sessions`

Records of support staff impersonating customer accounts for troubleshooting, with time-limited sessions and full action audit.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique session identifier |
| `admin_user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Support admin initiating impersonation |
| `customer_user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Customer account being impersonated |
| `reason` | TEXT | NOT NULL | Required justification for impersonation |
| `started_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Session start time |
| `ended_at` | TIMESTAMPTZ | NULLABLE | Session end time (NULL = still active) |
| `expires_at` | TIMESTAMPTZ | NOT NULL | Session expiry (maximum duration) |
| `is_active` | BOOLEAN | NOT NULL, DEFAULT true, INDEX | Whether session is currently active |
| `actions_taken` | JSONB | NOT NULL, DEFAULT '[]' | Chronological list of actions performed |

**Indexes:**
- `ix_support_impersonation_sessions_admin_user_id` on `admin_user_id`
- `ix_support_impersonation_sessions_customer_user_id` on `customer_user_id`
- `ix_support_impersonation_sessions_is_active` on `is_active`

**Relationships:**
- Many-to-one with `users` (admin_user_id, CASCADE DELETE)
- Many-to-one with `users` (customer_user_id, CASCADE DELETE)

**Security Notes:**
- All impersonation sessions are logged to `admin_audit_logs`
- Sessions have a hard expiry enforced at the database level
- `actions_taken` provides an immutable trail of all actions during the session

---

## Compliance (February 2026)

Legal and regulatory compliance tables.

> **Note:** `tos_consent_records` and `gdpr_data_requests` were initially documented in the ML Data Strategy section above. The entries below reflect the actual database schema as verified February 28, 2026, including columns not previously documented.

#### `tos_consent_records` (Updated Schema)

Tracks user consent for Terms of Service and Privacy Policy with IP and user agent capture for GDPR/LGPD compliance. See also the ML Data Strategy section for context.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique consent identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | User who consented |
| `tos_version` | VARCHAR(20) | NOT NULL | Terms of Service version accepted |
| `privacy_policy_version` | VARCHAR(20) | NOT NULL | Privacy Policy version accepted |
| `ml_data_collection_consent` | BOOLEAN | NOT NULL, DEFAULT true | Explicit consent for ML data collection |
| `consent_ip_address` | VARCHAR(45) | NULLABLE | IP address at time of consent |
| `consent_user_agent` | TEXT | NULLABLE | User agent string at consent |
| `consented_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | When consent was given |
| `withdrawn_at` | TIMESTAMPTZ | NULLABLE | When consent was withdrawn |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Record creation timestamp |

**Indexes:**
- `ix_tos_consent_records_user_id` on `user_id`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)
- One-to-many with `ml_training_data_provenance` (tos_consent_id, SET NULL)

---

#### `gdpr_data_requests` (Updated Schema)

Tracks GDPR Article 15 (access) and Article 17 (erasure) requests with full processing audit trail.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique request identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Requesting user |
| `request_type` | VARCHAR(20) | NOT NULL, INDEX | `export`, `deletion` |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'pending', INDEX | `pending`, `processing`, `completed`, `rejected` |
| `requester_email` | VARCHAR(255) | NOT NULL | Email for notification |
| `processed_at` | TIMESTAMPTZ | NULLABLE | Processing completion timestamp |
| `processed_by` | UUID | NULLABLE | Admin user ID who processed |
| `export_file_path` | VARCHAR(500) | NULLABLE | Path to generated export file |
| `export_expires_at` | TIMESTAMPTZ | NULLABLE | Export download expiry timestamp |
| `deletion_confirmed_at` | TIMESTAMPTZ | NULLABLE | Data deletion confirmation timestamp |
| `error_message` | TEXT | NULLABLE | Processing error message |
| `request_ip_address` | VARCHAR(45) | NULLABLE | IP address of requester |
| `request_user_agent` | TEXT | NULLABLE | User agent of requester |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now(), INDEX | Request submission timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_gdpr_data_requests_user_id` on `user_id`
- `ix_gdpr_data_requests_status` on `status`
- `ix_gdpr_data_requests_request_type` on `request_type`
- `ix_gdpr_data_requests_created_at` on `created_at`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)

---

## Alerts and User Feedback (February 2026)

### New Tables

#### `user_feedback`

General platform feedback submissions from users, separate from AI-specific ratings.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique feedback identifier |
| `user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | Submitting user |
| `category` | VARCHAR(50) | NOT NULL, INDEX | Feedback category (e.g., `bug`, `feature_request`, `general`) |
| `subject` | VARCHAR(255) | NOT NULL | Feedback subject line |
| `message` | TEXT | NOT NULL | Full feedback message |
| `contact_email` | VARCHAR(255) | NULLABLE | Optional contact email |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'pending', INDEX | `pending`, `in_review`, `resolved`, `closed` |
| `page_url` | VARCHAR(500) | NULLABLE | Page URL where feedback was submitted |
| `user_agent` | VARCHAR(500) | NULLABLE | Browser user agent string |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Submission timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_user_feedback_user_id` on `user_id`
- `ix_user_feedback_category` on `category`
- `ix_user_feedback_status` on `status`

**Relationships:**
- Many-to-one with `users` (user_id, CASCADE DELETE)

---

## JIRA Integration (February 2026)

Bidirectional JIRA issue synchronization for vulnerability tracking in external project management systems.

### New Tables

#### `jira_project_mappings`

Maps Apogee projects to JIRA projects for automatic issue creation and synchronization.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique mapping identifier |
| `integration_id` | UUID | NOT NULL, FK → integrations.id ON DELETE CASCADE, INDEX | Parent JIRA integration |
| `blocksecops_project_id` | UUID | NOT NULL, FK → projects.id ON DELETE CASCADE, INDEX | Apogee project |
| `jira_project_id` | VARCHAR(255) | NOT NULL | JIRA project ID |
| `jira_project_key` | VARCHAR(50) | NOT NULL | JIRA project key (e.g., `BSO`) |
| `jira_project_name` | VARCHAR(255) | NOT NULL | JIRA project display name |
| `issue_type` | VARCHAR(100) | NOT NULL, DEFAULT 'Bug' | JIRA issue type for created issues |
| `auto_create_issues` | BOOLEAN | NOT NULL, DEFAULT true | Auto-create issues for new vulnerabilities |
| `min_severity_to_sync` | VARCHAR(20) | NOT NULL, DEFAULT 'medium' | Minimum severity threshold for sync |
| `field_mappings` | JSONB | NULLABLE, DEFAULT '{}' | Custom field mapping configuration |
| `issues_created` | INTEGER | NOT NULL, DEFAULT 0 | Total issues created via this mapping |
| `last_sync_at` | TIMESTAMPTZ | NULLABLE | Last synchronization timestamp |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_jira_project_mappings_integration_id` on `integration_id`
- `ix_jira_project_mappings_blocksecops_project_id` on `blocksecops_project_id`
- `ix_jira_project_mappings_unique` UNIQUE on (`integration_id`, `jira_project_id`)

**Relationships:**
- Many-to-one with `integrations` (integration_id, CASCADE DELETE)
- Many-to-one with `projects` (blocksecops_project_id, CASCADE DELETE)
- One-to-many with `jira_issue_syncs` (CASCADE DELETE)

---

#### `jira_issue_syncs`

Individual vulnerability-to-JIRA-issue synchronization records tracking issue state.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique sync record identifier |
| `mapping_id` | UUID | NOT NULL, FK → jira_project_mappings.id ON DELETE CASCADE, INDEX | Parent project mapping |
| `vulnerability_id` | UUID | NOT NULL, FK → vulnerabilities.id ON DELETE CASCADE, INDEX | Synced vulnerability |
| `jira_issue_id` | VARCHAR(255) | NOT NULL | JIRA internal issue ID |
| `jira_issue_key` | VARCHAR(50) | NOT NULL, INDEX | JIRA issue key (e.g., `BSO-42`) |
| `jira_issue_url` | VARCHAR(2048) | NOT NULL | JIRA issue URL |
| `jira_status` | VARCHAR(100) | NULLABLE | Current JIRA issue status |
| `last_synced_at` | TIMESTAMPTZ | NULLABLE | Last bidirectional sync timestamp |
| `sync_direction` | VARCHAR(20) | NOT NULL, DEFAULT 'outbound' | `outbound` (Apogee→JIRA) or `bidirectional` |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Sync record creation timestamp |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |

**Indexes:**
- `ix_jira_issue_syncs_mapping_id` on `mapping_id`
- `ix_jira_issue_syncs_vulnerability_id` on `vulnerability_id`
- `ix_jira_issue_syncs_jira_issue_key` on `jira_issue_key`
- `ix_jira_issue_syncs_unique` UNIQUE on (`mapping_id`, `vulnerability_id`)

**Relationships:**
- Many-to-one with `jira_project_mappings` (mapping_id, CASCADE DELETE)
- Many-to-one with `vulnerabilities` (vulnerability_id, CASCADE DELETE)

---

## Referral System (March 2026)

User referral program with configurable thresholds and reward tracking. Referrers earn free subscription months when referred users sign up.

### New Tables

#### `platform_settings`

Admin-configurable key-value store for platform-wide settings (initially used for referral configuration).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `key` | VARCHAR(100) | PRIMARY KEY | Setting key identifier |
| `value` | TEXT | NOT NULL | JSON-encoded setting value |
| `description` | VARCHAR(500) | NULLABLE | Human-readable description |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Last update timestamp |
| `updated_by` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | Admin who last updated |

**Default Rows:**
| Key | Value | Description |
|-----|-------|-------------|
| `referral_threshold` | `3` | Number of referrals needed to earn a reward |
| `referral_reward_tier` | `team` | Tier granted as reward |
| `referral_reward_days` | `30` | Duration of reward in days |
| `referral_enabled` | `true` | Whether referral system is active |

**Relationships:**
- Many-to-one with `users` (updated_by, SET NULL on delete)

---

#### `referrals`

Tracks individual referral events between referrer and referred users.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique referral identifier |
| `referrer_user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | User who shared the referral code |
| `referred_user_id` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL, INDEX | User who signed up with the code |
| `referral_code` | VARCHAR(20) | NOT NULL, INDEX | The referral code used |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'completed' | Referral status |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |
| `completed_at` | TIMESTAMPTZ | NULLABLE | When the referred user signed up |

**Indexes:**
- `ix_referrals_referrer_user_id` on `referrer_user_id`
- `ix_referrals_referred_user_id` on `referred_user_id`
- `ix_referrals_referral_code` on `referral_code`

**Relationships:**
- Many-to-one with `users` (referrer_user_id, CASCADE delete)
- Many-to-one with `users` (referred_user_id, SET NULL on delete)

---

#### `referral_rewards`

Tracks rewards earned by referrers when they reach the referral threshold.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `id` | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique reward identifier |
| `referrer_user_id` | UUID | NOT NULL, FK → users.id ON DELETE CASCADE, INDEX | User who earned the reward |
| `reward_type` | VARCHAR(50) | NOT NULL, DEFAULT 'free_month' | Type of reward |
| `plan_tier` | VARCHAR(50) | NOT NULL, DEFAULT 'team' | Subscription tier granted |
| `status` | VARCHAR(20) | NOT NULL, DEFAULT 'pending' | pending / applied / expired |
| `qualifying_referral_count` | INTEGER | NOT NULL | Snapshot of referral count when earned |
| `applied_at` | TIMESTAMPTZ | NULLABLE | When the reward was applied to subscription |
| `expires_at` | TIMESTAMPTZ | NULLABLE | 90-day window to claim reward |
| `stripe_coupon_id` | VARCHAR(255) | NULLABLE | Stripe coupon ID when applied |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT now() | Creation timestamp |

**Indexes:**
- `ix_referral_rewards_referrer_user_id` on `referrer_user_id`

**Relationships:**
- Many-to-one with `users` (referrer_user_id, CASCADE delete)

---

### Modified Tables

#### `users` (Extended)

New columns added for referral system:

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| `referral_code` | VARCHAR(20) | UNIQUE, NULLABLE | User's personal referral code |
| `referred_by_user_id` | UUID | NULLABLE, FK → users.id ON DELETE SET NULL | User who referred this user |

**Indexes:**
- `uq_users_referral_code` UNIQUE on `referral_code`
- `ix_users_referred_by_user_id` on `referred_by_user_id`

---

**Last Updated**: March 1, 2026
