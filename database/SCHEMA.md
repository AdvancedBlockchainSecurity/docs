# Apogee Database Schema

**Database:** PostgreSQL 15.4 with pgvector extension
**Database Name:** `solidity_security`
**Schema:** `public`
**Timezone:** UTC
**Verified:** 2026-06-21 (migrations 083–096 fully reflected; scans + scanner_executions `failure_type` constraint extended to include all `ai_*` values per migration 096; 088 baseline columns + all tables covered below)
**Latest Migration:** 096 (extend failure_type CHECK constraint — ai_* values)

> **Naming Note:** The database is named `solidity_security`, not `blocksecops`. This name was established during initial development when the focus was solely on Solidity. Retained for backward compatibility.

**Total Tables:** 99 ORM-managed tables (excluding `alembic_version`) — adds `scanner_versions` (085), `scanner_version_history` (086), `contract_artifacts` (091), `stripe_event_log` (093), `ai_scan_metadata` (094), `byo_llm_keys` (095); migrations 083–084, 087, 090, 092, 096 are column/constraint-only (no new tables). Count verified 2026-06-21 against prod DB.

### Migration history delta since last full verification

| Migration | Date | Change | SCHEMA.md status |
|-----------|------|--------|------------------|
| 083 | 2026-03-16 | `support_tickets.ticket_number` column added | **Documented** — see Domain 14 |
| 084 | 2026-03-16 | `support_tickets.organization_id` column added | **Documented** — see Domain 14 |
| 085 | 2026-03-17 | **NEW** `scanner_versions` table | **Documented** — see Domain 12 |
| 086 | 2026-04-15 | **NEW** `scanner_version_history` table | **Documented** — see Domain 12 |
| 087 | 2026-04-17 | `integration_credentials` + 8 GitHub App BYO fields | **Documented** — see Domain 9 |
| 088 | 2026-04-21 | `contracts.baseline_scan_id` + `contracts.baseline_marked_at` + FK + index | **Documented** — see `contracts` in Domain 2 |
| 089 | 2026-05-08 | **NEW** `scanner_executions` table (per-scanner row per scan) | **Documented** — see Domain 2 |
| 090 | 2026-05-09 | `scans.failure_type` + `scanner_executions.failure_type` (VARCHAR(50), nullable, CHECK enum) | **Documented** — see `scans` and `scanner_executions` in Domain 2 |
| 091 | 2026-05-09 | `contracts.has_compiled_artifacts` + `contracts.artifact_layout` + **NEW** `contract_artifacts` table | **Documented** — see `contracts` and `contract_artifacts` in Domain 2 |
| 092 | 2026-06-20 | Partial UNIQUE index `users_stripe_customer_id_uniq` on `users(stripe_customer_id) WHERE stripe_customer_id IS NOT NULL` (BSO-SEC-022) | **Documented** — see `users` in Domain 1 |
| 093 | 2026-06-20 | **NEW** `stripe_event_log` table for webhook idempotency (BSO-SEC-024) | **Documented** — see Domain 1 (Stripe) |
| 094 | 2026-06-20 | **NEW** `ai_scan_metadata` table (Phase 10); `users.ai_consent_at`, `organizations.{ai_scanning_enabled,ai_input_tokens_used,ai_output_tokens_used,ai_quota_reset_at}`, `contracts.ai_processing_disabled` columns | **Documented** — see `users` / `organizations` / `contracts` rows + new AI Scanning section |
| 095 | 2026-06-20 | **NEW** `byo_llm_keys` table (Phase 10, BYO LLM API key storage, AES-256-GCM at rest) + FK from `ai_scan_metadata.byo_key_id` | **Documented** — see AI Scanning section |
| 096 | 2026-06-20 | Extends `failure_type` CHECK constraint on `scans` and `scanner_executions` to include all `ai_*` values: `ai_org_disabled`, `ai_contract_blocked`, `ai_token_cap_exceeded`, `ai_quota_exceeded`, `ai_safety_blocked`, `ai_output_invalid`, `ai_provider_error`, `ai_key_invalid`, `ai_system_error`, `ai_canceled` (BSO-SEC-040) | **Documented** — see `scans` and `scanner_executions` in Domain 2 |

---

## Table of Contents

1. [Core Domain: Users, Organizations, Teams](#1-core-domain-users-organizations-teams)
2. [Scanning Domain: Contracts, Scans, Vulnerabilities](#2-scanning-domain-contracts-scans-vulnerabilities)
3. [Intelligence Domain: Patterns, Fingerprints, Deduplication](#3-intelligence-domain-patterns-fingerprints-deduplication)
4. [Billing Domain: Subscriptions, Payments, Credits](#4-billing-domain-subscriptions-payments-credits)
5. [Auth Domain: API Keys, Sessions, Tokens](#5-auth-domain-api-keys-sessions-tokens)
6. [Audit Domain: Audit Logs, Activity Logs](#6-audit-domain-audit-logs-activity-logs)
7. [Collaboration Domain: Teams, Access, Comments](#7-collaboration-domain-teams-access-comments)
8. [Notifications Domain: Webhooks, Channels](#8-notifications-domain-webhooks-channels)
9. [Integrations Domain: GitHub, GitLab, JIRA](#9-integrations-domain-github-gitlab-jira)
10. [AI/Copilot Domain: Conversations, Repairs, Reviews, Invariants](#10-aicopilot-domain-conversations-repairs-reviews-invariants)
11. [Monitoring Domain: Monitored Contracts, Alerts](#11-monitoring-domain-monitored-contracts-alerts)
12. [Scanner Results Domain: Quality, Gas, Fuzzing, Formal Verification](#12-scanner-results-domain-quality-gas-fuzzing-formal-verification)
13. [ML/Compliance Domain: Consent, Provenance, GDPR](#13-mlcompliance-domain-consent-provenance-gdpr)
14. [Platform Domain: Settings, Referrals, Feedback, Support](#14-platform-domain-settings-referrals-feedback-support)
15. [ENUM Types](#15-enum-types)
16. [Trigger Functions](#16-trigger-functions)

---

## 1. Core Domain: Users, Organizations, Teams

### `users`

Central user table with authentication, wallet, admin, and tier fields.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| email | VARCHAR(255) | UNIQUE, NOT NULL, indexed | |
| display_name | VARCHAR(255) | nullable | |
| hashed_password | VARCHAR(255) | NOT NULL | |
| is_active | BOOLEAN | NOT NULL, default true | |
| is_superuser | BOOLEAN | NOT NULL, default false | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now(), on update | |
| default_organization_id | UUID | FK organizations(id) ON DELETE SET NULL, nullable, indexed | Migration 072 |
| tier | VARCHAR(20) | NOT NULL, default 'developer', indexed | developer/starter/growth/enterprise |
| tier_updated_at | TIMESTAMPTZ | nullable, default now() | |
| supabase_user_id | UUID | UNIQUE, nullable, indexed | |
| stripe_customer_id | VARCHAR(255) | nullable, **partial UNIQUE** | Migration 092 (BSO-SEC-022). Index `users_stripe_customer_id_uniq` with `WHERE stripe_customer_id IS NOT NULL` preserves multi-NULL semantics |
| stripe_subscription_id | VARCHAR(255) | nullable | |
| ai_consent_at | TIMESTAMPTZ | nullable | Migration 094 (Phase 10). NULL = user has not consented to AI sub-processor disclosure; AI scans rejected until set |
| wallet_address | VARCHAR(42) | UNIQUE, nullable, indexed | EVM MetaMask/WalletConnect |
| wallet_nonce | VARCHAR(64) | nullable | |
| wallet_linked_at | TIMESTAMPTZ | nullable | |
| ens_name | VARCHAR(255) | nullable, indexed | |
| solana_wallet_address | VARCHAR(44) | UNIQUE, nullable, indexed | Solana Phantom wallet |
| solana_wallet_nonce | VARCHAR(64) | nullable | |
| solana_wallet_linked_at | TIMESTAMPTZ | nullable | |
| admin_role | VARCHAR(50) | nullable, indexed | super_admin/platform_admin/support_admin |
| admin_mfa_enabled | BOOLEAN | NOT NULL, default false | |
| admin_mfa_secret | VARCHAR(255) | nullable | Encrypted TOTP secret |
| admin_last_activity | TIMESTAMPTZ | nullable | |
| admin_session_ip | VARCHAR(45) | nullable | |
| admin_created_by | UUID | nullable | |
| admin_created_at | TIMESTAMPTZ | nullable | |
| mfa_failed_attempts | INTEGER | NOT NULL, default 0 | Lockout tracking |
| mfa_locked_until | TIMESTAMPTZ | nullable | |
| mfa_last_failed_at | TIMESTAMPTZ | nullable | |
| referral_code | VARCHAR(20) | UNIQUE, nullable, indexed | Migration 078 |
| referred_by_user_id | UUID | FK users(id) ON DELETE SET NULL, nullable | Migration 078 |

### `organizations`

Multi-tenant organization support with SSO and Stripe billing.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| name | VARCHAR(255) | NOT NULL | |
| slug | VARCHAR(100) | UNIQUE, NOT NULL, indexed | |
| description | TEXT | nullable | |
| logo_url | VARCHAR(2048) | nullable | |
| tier | VARCHAR(50) | NOT NULL, default 'developer' | |
| stripe_customer_id | VARCHAR(255) | UNIQUE, nullable | |
| stripe_subscription_id | VARCHAR(255) | nullable | |
| ai_scanning_enabled | BOOLEAN | NOT NULL, default false | Migration 094 (Phase 10). Org-admin opt-in gate for AI scans; default OFF |
| ai_input_tokens_used | INTEGER | NOT NULL, default 0 | Monthly token budget bookkeeping; reset by Celery beat |
| ai_output_tokens_used | INTEGER | NOT NULL, default 0 | Monthly token budget bookkeeping; reset by Celery beat |
| ai_quota_reset_at | TIMESTAMPTZ | nullable | Last quota reset timestamp |
| sso_enabled | BOOLEAN | NOT NULL, default false | |
| sso_provider | VARCHAR(50) | nullable | saml, oidc |
| sso_config | JSONB | nullable | |
| sso_domain | VARCHAR(255) | nullable, indexed | |
| settings | JSONB | nullable, default '{}' | |
| owner_id | UUID | FK users(id) ON DELETE SET NULL, nullable, indexed | |
| is_active | BOOLEAN | NOT NULL, default true | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `organization_members`

Membership with RBAC role assignment.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| organization_id | UUID | FK organizations(id) ON DELETE CASCADE, NOT NULL, indexed | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| role_id | UUID | FK roles(id) ON DELETE RESTRICT, NOT NULL, indexed | |
| invited_by | UUID | nullable | |
| invited_at | TIMESTAMPTZ | nullable | |
| joined_at | TIMESTAMPTZ | NOT NULL, default now() | |
| is_active | BOOLEAN | NOT NULL, default true | |

### `roles`

RBAC role definitions (system and custom).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| organization_id | UUID | FK organizations(id) ON DELETE CASCADE, nullable, indexed | |
| name | VARCHAR(100) | NOT NULL | |
| display_name | VARCHAR(255) | NOT NULL | |
| description | TEXT | nullable | |
| permissions | JSONB | NOT NULL, default '[]' | |
| is_system_role | BOOLEAN | NOT NULL, default false | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `user_quotas`

Tier-based quota limits and usage tracking. Auto-populated by `create_user_quota()` trigger on user insert.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, UNIQUE, NOT NULL, indexed | |
| tier | VARCHAR(20) | NOT NULL, default 'developer', indexed | developer/starter/growth/enterprise |
| monthly_scan_limit | INTEGER | NOT NULL, default 3 | dev:3, starter:25, growth:75, enterprise:-1 |
| monthly_scans_used | INTEGER | NOT NULL, default 0 | |
| max_files_per_scan | INTEGER | NOT NULL, default -1 | -1 = unlimited |
| max_loc_per_scan | INTEGER | NOT NULL, default -1 | |
| scan_priority | INTEGER | NOT NULL, default 50 | Lower = higher priority |
| webhooks_enabled | BOOLEAN | NOT NULL, default false | |
| api_access_enabled | BOOLEAN | NOT NULL, default false | |
| export_enabled | BOOLEAN | NOT NULL, default true | |
| result_retention_days | INTEGER | NOT NULL, default 7 | dev:7, starter:90, growth:365, ent:365 |
| max_projects | INTEGER | NOT NULL, default 3 | dev:3, starter:15, growth:-1, ent:-1 |
| max_team_members | INTEGER | NOT NULL, default 2 | |
| monthly_api_calls_limit | INTEGER | NOT NULL, default 0 | |
| monthly_api_calls_used | INTEGER | NOT NULL, default 0 | |
| monthly_ai_explanations_limit | INTEGER | NOT NULL, default 0 | dev:0, starter:75, growth:300, ent:-1 |
| monthly_ai_explanations_used | INTEGER | NOT NULL, default 0 | |
| concurrent_scans_limit | INTEGER | NOT NULL, default 1 | |
| web_requests_per_minute | INTEGER | NOT NULL, default 60 | |
| api_requests_per_minute | INTEGER | NOT NULL, default 0 | |
| api_requests_per_hour | INTEGER | NOT NULL, default 0 | |
| quota_reset_at | TIMESTAMPTZ | NOT NULL, default first of next month | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `user_preferences`

User notification and UI preferences (1:1 with users).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| user_id | UUID | PK, FK users(id) ON DELETE CASCADE | |
| email_notifications | BOOLEAN | NOT NULL, default true | |
| scan_completion_notifications | BOOLEAN | NOT NULL, default true | |
| critical_vulnerability_alerts | BOOLEAN | NOT NULL, default true | |
| weekly_digest | BOOLEAN | NOT NULL, default false | |
| theme | VARCHAR(20) | NOT NULL, default 'light' | |
| timezone | VARCHAR(50) | NOT NULL, default 'UTC' | |
| language | VARCHAR(10) | NOT NULL, default 'en' | |
| preferences | JSONB | nullable, default '{}' | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

---

## 2. Scanning Domain: Contracts, Scans, Vulnerabilities

### `contracts`

Smart contract source code and metadata.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id), NOT NULL, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE SET NULL, nullable, indexed | |
| name | VARCHAR(255) | NOT NULL | |
| address | VARCHAR(42) | nullable, indexed | On-chain address |
| network | VARCHAR(50) | NOT NULL, default 'ethereum' | |
| source_code | TEXT | nullable | |
| bytecode | TEXT | nullable | |
| lines_of_code | INTEGER | NOT NULL, default 0 | |
| is_multi_file | BOOLEAN | NOT NULL, default false | |
| main_file_path | VARCHAR(500) | nullable | |
| file_count | INTEGER | NOT NULL, default 1 | |
| total_lines_of_code | INTEGER | NOT NULL, default 0 | |
| framework | VARCHAR(50) | nullable, indexed | foundry/hardhat/plain |
| framework_config | JSONB | nullable | |
| language | ENUM(contract_language) | NOT NULL, default 'solidity', indexed | 20 supported languages |
| compiler_version | VARCHAR(50) | nullable | |
| language_metadata | JSONB | nullable | |
| status | ENUM(contract_status) | NOT NULL, default 'uploaded' | uploaded/pending/scanning/scanned/failed |
| structure_analyzed | BOOLEAN | NOT NULL, default false | |
| structure_analyzed_at | TIMESTAMPTZ | nullable | |
| structure_parse_errors | JSONB | nullable | |
| source_hash | VARCHAR(64) | nullable, indexed | SHA-256 content hash |
| source_repo_url | VARCHAR(500) | nullable | Provenance: original GitHub URL (populated by `/api/v1/contracts/from-github` since api-service 0.37.x; OAuth-linked sync also populates) |
| source_commit_hash | VARCHAR(40) | nullable | Provenance: branch HEAD SHA at fetch time |
| source_file_path | VARCHAR(500) | nullable | Provenance: repo-relative path |
| is_archived | BOOLEAN | NOT NULL, default false | ML data preservation |
| archived_at | TIMESTAMPTZ | nullable | |
| baseline_scan_id | UUID | FK scans(id) ON DELETE SET NULL, nullable, indexed | Scan marked as the canonical baseline for this contract. Set via `PUT /api/v1/contracts/{id}/baseline`. Migration 088. |
| baseline_marked_at | TIMESTAMPTZ | nullable | When the current `baseline_scan_id` was set. Null when no baseline. Migration 088. |
| ai_processing_disabled | BOOLEAN | NOT NULL, default false | Migration 094 (Phase 10). Per-contract sensitivity tag. When true, AI scans rejected with `failure_type=ai_contract_blocked` |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `contract_files`

Individual files within multi-file contracts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| contract_id | UUID | FK contracts(id) ON DELETE CASCADE, NOT NULL, indexed | |
| file_path | VARCHAR(500) | NOT NULL | Relative path |
| file_content | TEXT | NOT NULL | |
| is_main_file | BOOLEAN | NOT NULL, default false | |
| file_size | INTEGER | NOT NULL | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `contract_archives`

Compressed source backups for archived contracts (ML data preservation).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| contract_id | UUID | FK contracts(id) ON DELETE CASCADE, UNIQUE, NOT NULL | |
| source_hash | VARCHAR(64) | NOT NULL | |
| provider | VARCHAR(50) | nullable | github, gitlab |
| repo_full_name | VARCHAR(500) | nullable | |
| commit_hash | VARCHAR(40) | nullable | |
| file_path | VARCHAR(500) | nullable | |
| compressed_source | BYTEA | nullable | Fallback when no external ref |
| archived_at | TIMESTAMPTZ | NOT NULL, default now() | |
| archived_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| last_restored_at | TIMESTAMPTZ | nullable | |
| restore_count | INTEGER | NOT NULL, default 0 | |

### `contract_functions`

Parsed function definitions from contract source code.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| contract_id | UUID | FK contracts(id) ON DELETE CASCADE, NOT NULL, indexed | |
| name | VARCHAR(255) | NOT NULL, indexed | |
| selector | VARCHAR(10) | nullable, indexed | 4-byte function selector |
| visibility | VARCHAR(20) | NOT NULL | public/external/internal/private |
| state_mutability | VARCHAR(20) | nullable | pure/view/payable/nonpayable |
| is_constructor | BOOLEAN | NOT NULL, default false | |
| is_fallback | BOOLEAN | NOT NULL, default false | |
| is_receive | BOOLEAN | NOT NULL, default false | |
| parameters | JSONB | nullable | [{name, type, storage_location}] |
| return_types | JSONB | nullable | |
| modifiers | JSONB | nullable | [{name, arguments}] |
| start_line | INTEGER | nullable | |
| end_line | INTEGER | nullable | |
| natspec | JSONB | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `contract_events`

Parsed event definitions from contract source code.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| contract_id | UUID | FK contracts(id) ON DELETE CASCADE, NOT NULL, indexed | |
| name | VARCHAR(255) | NOT NULL, indexed | |
| signature | VARCHAR(500) | nullable | |
| topic0 | VARCHAR(66) | nullable, indexed | Keccak256 hash |
| parameters | JSONB | NOT NULL | [{name, type, indexed}] |
| anonymous | BOOLEAN | NOT NULL, default false | |
| start_line | INTEGER | nullable | |
| natspec | JSONB | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `contract_state_variables`

Parsed state variable definitions from contract source code.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| contract_id | UUID | FK contracts(id) ON DELETE CASCADE, NOT NULL, indexed | |
| name | VARCHAR(255) | NOT NULL, indexed | |
| type_name | VARCHAR(500) | NOT NULL | |
| visibility | VARCHAR(20) | NOT NULL | |
| mutability | VARCHAR(20) | nullable | constant/immutable |
| storage_slot | INTEGER | nullable | |
| initial_value | TEXT | nullable | |
| start_line | INTEGER | nullable | |
| natspec | JSONB | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `contract_tags`

User-scoped custom tags for organizing contracts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| name | VARCHAR(50) | NOT NULL | |
| color | VARCHAR(7) | NOT NULL | Hex color |
| description | VARCHAR(255) | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_contract_tags_user_name` (user_id, name) UNIQUE

### `contract_tag_associations`

Junction table: contracts to tags (M:N).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| contract_id | UUID | FK contracts(id) ON DELETE CASCADE, NOT NULL, indexed | |
| tag_id | UUID | FK contract_tags(id) ON DELETE CASCADE, NOT NULL, indexed | |
| assigned_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_contract_tag_associations_unique` (contract_id, tag_id) UNIQUE

### `projects`

Logical groupings of related contracts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| name | VARCHAR(255) | NOT NULL, indexed | |
| description | TEXT | nullable | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE SET NULL, nullable, indexed | |
| settings | JSONB | NOT NULL, default '{}' | |
| default_scan_profile | VARCHAR(50) | NOT NULL, default 'standard' | |
| created_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `project_contracts`

Junction table: projects to contracts (M:N).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| project_id | UUID | PK, FK projects(id) ON DELETE CASCADE | |
| contract_id | UUID | PK, FK contracts(id) ON DELETE CASCADE | |
| added_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `scans`

Scan execution tracking with priority queue support.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| contract_id | UUID | FK contracts(id), NOT NULL, indexed | |
| user_id | UUID | FK users(id), NOT NULL, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE SET NULL, nullable, indexed | |
| scan_type | VARCHAR(50) | NOT NULL, default 'full' | |
| status | ENUM(scan_status) | NOT NULL, default 'queued' | queued/running/completed/failed/cancelled |
| started_at | TIMESTAMPTZ | nullable | |
| completed_at | TIMESTAMPTZ | nullable | |
| error_message | TEXT | nullable | |
| failure_type | VARCHAR(50) | nullable, CHECK constraint | Migration 090 (initial). Migration 096 extended CHECK to include all `ai_*` values (BSO-SEC-040). Full enum: `unsupported_solidity_version`, `compile_error`, `timeout`, `oom`, `internal_error`, `scanner_skipped`, `ai_org_disabled`, `ai_contract_blocked`, `ai_token_cap_exceeded`, `ai_quota_exceeded`, `ai_safety_blocked`, `ai_output_invalid`, `ai_provider_error`, `ai_key_invalid`, `ai_system_error`, `ai_canceled`. Set when `status='failed'` to let the dashboard branch the failure presentation. |
| critical_count | INTEGER | NOT NULL, default 0 | |
| high_count | INTEGER | NOT NULL, default 0 | |
| medium_count | INTEGER | NOT NULL, default 0 | |
| low_count | INTEGER | NOT NULL, default 0 | |
| priority | INTEGER | NOT NULL, default 50, indexed | Lower = higher priority |
| scanners_used | VARCHAR(50)[] | nullable | Array of scanner IDs |
| scan_config | JSONB | nullable, default '{}' | |
| duration_seconds | INTEGER | nullable | |
| batch_id | UUID | FK scan_batches(id) ON DELETE SET NULL, nullable, indexed | |
| scan_source | VARCHAR(50) | NOT NULL, default 'web', indexed | web/cli/vscode/github_actions/etc. |
| retry_count | INTEGER | NOT NULL, default 0 | |
| last_retry_at | TIMESTAMPTZ | nullable | |
| retry_reason | VARCHAR(200) | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `scan_batches`

Batch scan operations for multi-contract scans.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| project_id | UUID | FK projects(id) ON DELETE SET NULL, nullable, indexed | |
| total_contracts | INTEGER | NOT NULL | |
| completed_count | INTEGER | NOT NULL, default 0 | |
| failed_count | INTEGER | NOT NULL, default 0 | |
| status | VARCHAR(50) | NOT NULL, default 'pending', indexed | |
| priority | VARCHAR(20) | NOT NULL, default 'normal' | low/normal/high |
| scanner_ids | VARCHAR(50)[] | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |
| completed_at | TIMESTAMPTZ | nullable | |

### `scanner_executions`

Per-scanner execution row for each scan (Migration 089). One row per requested scanner per scan, regardless of outcome. Lets the dashboard display per-scanner status (queued / running / completed / failed / skipped / timeout) without packing the data into a JSON blob on `scans`.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK, default gen_random_uuid() | |
| scan_id | UUID | FK scans(id) ON DELETE CASCADE, NOT NULL, indexed | |
| scanner_id | VARCHAR(50) | NOT NULL | e.g. `slither`, `mythril`, `wake` |
| status | VARCHAR(20) | NOT NULL, default 'queued' | queued/running/completed/failed/skipped/timeout |
| started_at | TIMESTAMPTZ | nullable | |
| completed_at | TIMESTAMPTZ | nullable | |
| exit_code | INTEGER | nullable | Scanner process exit code |
| error_message | TEXT | nullable | Per-scanner error text |
| failure_type | VARCHAR(50) | nullable, CHECK constraint | Migration 090 (initial); constraint extended by migration 096 to include all `ai_*` values — same full enum as `scans.failure_type`. Lets a single failed scanner be classified independently of the overall scan. |
| duration_seconds | INTEGER | nullable | |
| image_tag | VARCHAR(255) | nullable | Scanner image tag the execution ran on (e.g., `0.4.1`) |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now(), on update | |

**Indexes:** `(scan_id, scanner_id)` for per-scan lookups; `(scan_id)` alone for the GET `/scans/{id}/executions` endpoint.

**Endpoint:** `GET /api/v1/scans/{scan_id}/executions` returns the rows for a scan.

### `vulnerabilities`

Detected vulnerabilities with intelligence layer fields, soft-delete for ML preservation.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| scan_id | UUID | FK scans(id), NOT NULL, indexed | |
| contract_id | UUID | FK contracts(id) ON DELETE SET NULL, nullable, indexed | SET NULL for soft-delete |
| title | VARCHAR(255) | NOT NULL | |
| description | TEXT | NOT NULL | |
| severity | ENUM(vulnerability_severity) | NOT NULL, indexed | critical/high/medium/low |
| status | ENUM(vulnerability_status) | NOT NULL, default 'open' | open/acknowledged/fixed/false_positive |
| swc_id | VARCHAR(100) | nullable | |
| line_number | INTEGER | nullable | |
| code_snippet | TEXT | nullable | |
| recommendation | TEXT | nullable | |
| scanner_id | VARCHAR(50) | nullable, indexed | |
| category | VARCHAR(100) | nullable, indexed | |
| confidence | NUMERIC(3,2) | nullable | |
| fingerprint_code | VARCHAR(64) | nullable, indexed | |
| fingerprint_ast | VARCHAR(64) | nullable | |
| fingerprint_location | VARCHAR(64) | nullable | |
| fingerprint_location_fuzzy | VARCHAR(64) | nullable, indexed | |
| fingerprint_semantic | VARCHAR(64) | nullable | |
| fingerprint_composite | VARCHAR(64) | nullable, indexed | |
| pattern_id | VARCHAR(50) | FK vulnerability_patterns(id) ON DELETE SET NULL, nullable, indexed | |
| pattern_code | VARCHAR(50) | nullable, indexed | |
| classification_confidence | FLOAT | nullable, indexed | |
| classification_method | VARCHAR(20) | nullable, indexed | |
| deduplication_group_id | UUID | FK deduplication_groups(id) ON DELETE SET NULL, nullable, indexed | |
| is_primary | BOOLEAN | NOT NULL, default true | Canonical finding in dedup group |
| duplicate_count | INTEGER | NOT NULL, default 0 | |
| deduplication_strategy | VARCHAR(20) | nullable, indexed | |
| similarity_score | FLOAT | nullable, indexed | |
| false_positive_score | FLOAT | nullable, indexed | |
| false_positive_reasons | TEXT[] | nullable | |
| scanner_confidence | FLOAT | nullable | |
| tool_consensus_score | FLOAT | nullable | |
| multi_class_prediction | JSONB | nullable | {confirmed, false_positive, wont_fix, needs_review} |
| predicted_class | VARCHAR(50) | nullable, indexed | |
| multi_class_model_version | VARCHAR(50) | nullable, indexed | |
| multi_class_predicted_at | TIMESTAMPTZ | nullable | |
| first_seen | TIMESTAMPTZ | nullable, indexed | |
| last_seen | TIMESTAMPTZ | nullable, indexed | |
| occurrence_count | INTEGER | NOT NULL, default 1 | |
| was_fixed | BOOLEAN | NOT NULL, default false | |
| reintroduced | BOOLEAN | NOT NULL, default false | |
| user_classification | VARCHAR(20) | nullable, indexed | |
| user_feedback | TEXT | nullable | |
| fix_verified | BOOLEAN | NOT NULL, default false | |
| fix_verified_at | TIMESTAMPTZ | nullable | |
| fix_verified_by | UUID | nullable | |
| file_path | VARCHAR(500) | nullable, indexed | |
| function_name | VARCHAR(200) | nullable, indexed | |
| contract_name | VARCHAR(200) | nullable, indexed | |
| first_viewed_at | TIMESTAMPTZ | nullable | |
| view_count | INTEGER | NOT NULL, default 0 | |
| last_viewed_at | TIMESTAMPTZ | nullable | |
| time_spent_viewing_ms | INTEGER | NOT NULL, default 0 | |
| detector_id | VARCHAR(200) | nullable, indexed | |
| raw_output | JSONB | nullable | |
| normalization_version | VARCHAR(20) | nullable | |
| detected_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |
| deleted_at | TIMESTAMPTZ | nullable, indexed | Soft-delete timestamp |
| deleted_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| deletion_reason | VARCHAR(50) | nullable | contract_deleted/scan_deleted/user_action |

---

## 3. Intelligence Domain: Patterns, Fingerprints, Deduplication

### `vulnerability_patterns`

Central knowledge base of 84+ vulnerability pattern definitions (BVD-* IDs).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | VARCHAR(50) | PK | e.g., BVD-SOLIDITY-REE-001, BVD-SOLANA-CPI-001 |
| name | VARCHAR(100) | NOT NULL | e.g., "Reentrancy Attack" |
| description | TEXT | NOT NULL | |
| category | VARCHAR(50) | NOT NULL | access-control, reentrancy, arithmetic, etc. |
| severity | VARCHAR(20) | NOT NULL | critical/high/medium/low |
| swc_id | VARCHAR(20) | nullable | SWC-107 |
| cwe_id | VARCHAR(20) | nullable | CWE-691 |
| owasp_category | VARCHAR(100) | nullable | |
| remediation | TEXT | nullable | |
| fix_examples | JSONB | nullable | |
| references | JSONB | nullable | |
| detection_methods | VARCHAR(50)[] | nullable | static/symbolic/fuzzing |
| false_positive_rate | FLOAT | nullable | 0.0-1.0 |
| affected_languages | VARCHAR(20)[] | NOT NULL | solidity/vyper/rust |
| semantic_description | TEXT | nullable | For ML embeddings |
| keywords | TEXT[] | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| is_active | BOOLEAN | NOT NULL, default true | |
| needs_review | BOOLEAN | NOT NULL, default false | |
| review_reason | VARCHAR(255) | nullable | |
| fp_feedback_count | INTEGER | NOT NULL, default 0 | |
| confirmed_feedback_count | INTEGER | NOT NULL, default 0 | |

### `pattern_tool_mappings`

Maps scanner detector IDs to vulnerability patterns for normalization.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| pattern_id | VARCHAR(50) | FK vulnerability_patterns(id) ON DELETE CASCADE, NOT NULL | |
| scanner_id | VARCHAR(50) | NOT NULL | slither/mythril/aderyn/etc. |
| detector_id | VARCHAR(200) | NOT NULL | e.g., reentrancy-eth |
| confidence_threshold | FLOAT | nullable | |
| match_type | VARCHAR(20) | NOT NULL, default 'exact' | exact/fuzzy/semantic |
| keywords_override | TEXT[] | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| is_active | BOOLEAN | NOT NULL, default true | |

### `deduplication_groups`

Groups of duplicate vulnerabilities identified across scanners.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| canonical_finding_id | UUID | FK vulnerabilities(id) ON DELETE SET NULL, nullable | Primary finding |
| contract_id | UUID | FK contracts(id) ON DELETE CASCADE, NOT NULL | |
| pattern_code | VARCHAR(50) | FK vulnerability_patterns(id) ON DELETE SET NULL, nullable | |
| group_size | INTEGER | NOT NULL, default 1 | |
| strategy | VARCHAR(20) | NOT NULL | exact/fuzzy/semantic |
| confidence | FLOAT | NOT NULL | 0.0-1.0 |
| fingerprint_code | VARCHAR(64) | nullable | |
| fingerprint_ast | VARCHAR(64) | nullable | |
| fingerprint_semantic | VARCHAR(64) | nullable | |
| severity_distribution | JSONB | nullable | {"critical":2,"high":3} |
| scanner_distribution | JSONB | nullable | {"slither":3,"mythril":2} |
| first_detected | TIMESTAMPTZ | NOT NULL | |
| last_updated | TIMESTAMPTZ | NOT NULL | |
| verified | BOOLEAN | NOT NULL, default false | |
| verified_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| verified_at | TIMESTAMPTZ | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |

### `vulnerability_classifications`

User feedback and manual classification history for ML training.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| vulnerability_id | UUID | FK vulnerabilities(id) ON DELETE CASCADE, NOT NULL | |
| user_id | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| classification | VARCHAR(20) | NOT NULL | confirmed/false_positive/wont_fix/duplicate/needs_review |
| previous_classification | VARCHAR(20) | nullable | |
| confidence | FLOAT | nullable | 0.0-1.0 |
| feedback_text | TEXT | nullable | |
| tags | VARCHAR(50)[] | nullable | |
| fix_status | VARCHAR(20) | nullable | fixing/fixed/verified/reopened |
| fix_commit_hash | VARCHAR(64) | nullable | |
| fix_verified | BOOLEAN | NOT NULL, default false | |
| fix_verified_at | TIMESTAMPTZ | nullable | |
| was_actually_vulnerable | BOOLEAN | nullable | Ground truth for ML |
| exploitability_score | FLOAT | nullable | 0.0-1.0 |
| business_impact | VARCHAR(20) | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| is_latest | BOOLEAN | NOT NULL, default true | |

### `vulnerability_trends`

Time-series analytics for vulnerability patterns.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| pattern_id | VARCHAR(50) | FK vulnerability_patterns(id) ON DELETE CASCADE, NOT NULL | |
| contract_id | UUID | FK contracts(id) ON DELETE CASCADE, nullable | NULL = platform-wide |
| user_id | UUID | FK users(id) ON DELETE CASCADE, nullable | |
| period_start | TIMESTAMPTZ | NOT NULL | |
| period_end | TIMESTAMPTZ | NOT NULL | |
| period_type | VARCHAR(20) | NOT NULL | hourly/daily/weekly/monthly |
| total_occurrences | INTEGER | NOT NULL, default 0 | |
| unique_contracts | INTEGER | NOT NULL, default 0 | |
| new_occurrences | INTEGER | NOT NULL, default 0 | |
| reintroduced_occurrences | INTEGER | NOT NULL, default 0 | |
| critical_count | INTEGER | NOT NULL, default 0 | |
| high_count | INTEGER | NOT NULL, default 0 | |
| medium_count | INTEGER | NOT NULL, default 0 | |
| low_count | INTEGER | NOT NULL, default 0 | |
| open_count | INTEGER | NOT NULL, default 0 | |
| fixed_count | INTEGER | NOT NULL, default 0 | |
| false_positive_count | INTEGER | NOT NULL, default 0 | |
| acknowledged_count | INTEGER | NOT NULL, default 0 | |
| scanner_distribution | JSONB | nullable | |
| avg_time_to_fix | FLOAT | nullable | Hours |
| fix_rate | FLOAT | nullable | 0.0-1.0 |
| reintroduction_rate | FLOAT | nullable | |
| avg_false_positive_score | FLOAT | nullable | |
| avg_confidence | FLOAT | nullable | |
| duplicate_rate | FLOAT | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |

### `exploits`

Historical real-world exploit database with pgvector embeddings for RAG.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| source | VARCHAR(50) | NOT NULL | rekt.news/defillama/immunefi |
| source_id | VARCHAR(100) | nullable | |
| source_url | TEXT | nullable | |
| protocol | VARCHAR(100) | NOT NULL, indexed | |
| chain | VARCHAR(50) | NOT NULL, indexed | ethereum/bsc/polygon |
| contract_addresses | VARCHAR(42)[] | nullable | |
| date | TIMESTAMPTZ | NOT NULL, indexed | |
| loss_usd | NUMERIC(20,2) | nullable | |
| funds_recovered | NUMERIC(20,2) | nullable | |
| attack_vector | VARCHAR(100) | NOT NULL, indexed | reentrancy/flash_loan/oracle |
| root_cause | VARCHAR(200) | nullable | |
| vulnerability_types | VARCHAR(50)[] | nullable | |
| title | VARCHAR(200) | NOT NULL | |
| description | TEXT | NOT NULL | |
| technical_analysis | TEXT | nullable | |
| code_snippet | TEXT | nullable | |
| tx_hashes | VARCHAR(66)[] | nullable | |
| embedding | vector(1536) | nullable | pgvector for semantic search |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| is_verified | BOOLEAN | NOT NULL, default false | |

**Indexes:** `ix_exploits_embedding` (ivfflat, vector_cosine_ops, lists=100)

### `cves`

CVE database for smart contract security with pgvector embeddings.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| cve_id | VARCHAR(20) | UNIQUE, NOT NULL, indexed | CVE-2024-12345 |
| cwe_id | VARCHAR(20) | nullable, indexed | |
| severity | VARCHAR(20) | NOT NULL, indexed | |
| cvss_score | FLOAT | nullable | 0.0-10.0 |
| cvss_vector | VARCHAR(100) | nullable | |
| title | VARCHAR(200) | NOT NULL | |
| description | TEXT | NOT NULL | |
| remediation | TEXT | nullable | |
| affected_languages | VARCHAR(20)[] | NOT NULL | |
| affected_products | VARCHAR(100)[] | nullable | |
| vulnerability_type | VARCHAR(100) | nullable | |
| references | JSONB | nullable | |
| pattern_ids | VARCHAR(50)[] | nullable | |
| published_at | TIMESTAMPTZ | nullable | |
| modified_at | TIMESTAMPTZ | nullable | |
| embedding | vector(1536) | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| source | VARCHAR(50) | NOT NULL, default 'nvd' | |

**Indexes:** `ix_cves_embedding` (ivfflat, vector_cosine_ops, lists=100)

### `scanner_quality_metrics`

Dynamic scanner quality tracking from user feedback.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | INTEGER | PK, autoincrement | |
| scanner_id | VARCHAR(50) | UNIQUE, NOT NULL, indexed | |
| total_findings | INTEGER | NOT NULL, default 0 | |
| confirmed_count | INTEGER | NOT NULL, default 0 | |
| false_positive_count | INTEGER | NOT NULL, default 0 | |
| wont_fix_count | INTEGER | NOT NULL, default 0 | |
| confirmation_rate | FLOAT | nullable | |
| false_positive_rate | FLOAT | nullable | |
| precision_score | FLOAT | nullable | |
| user_override_count | INTEGER | NOT NULL, default 0 | |
| avg_user_confidence | FLOAT | nullable | |
| user_preference_score | FLOAT | NOT NULL, default 0.5 | |
| calculated_priority | INTEGER | NOT NULL, default 50 | |
| manual_priority_override | INTEGER | nullable | |
| last_calculated_at | TIMESTAMPTZ | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |

### `implicit_labels`

Implicit labels inferred from user actions for ML training.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| vulnerability_id | UUID | FK vulnerabilities(id) ON DELETE CASCADE, NOT NULL, indexed | |
| label | VARCHAR(50) | NOT NULL | confirmed/false_positive/wont_fix |
| confidence | FLOAT | NOT NULL | |
| source | VARCHAR(50) | NOT NULL | status_change/view_pattern |
| action_type | VARCHAR(100) | NOT NULL | e.g., status:open->fixed |
| previous_value | VARCHAR(100) | nullable | |
| new_value | VARCHAR(100) | NOT NULL | |
| user_id | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| is_active | BOOLEAN | NOT NULL, default true | False if overridden |
| metadata | JSONB | nullable | Column name: metadata |

---

## 4. Billing Domain: Subscriptions, Payments, Credits

### `subscriptions`

Stripe subscription tracking.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE SET NULL, nullable, indexed | |
| stripe_subscription_id | VARCHAR(255) | UNIQUE, NOT NULL | |
| stripe_customer_id | VARCHAR(255) | NOT NULL, indexed | |
| stripe_price_id | VARCHAR(255) | nullable | |
| plan_tier | VARCHAR(50) | NOT NULL, indexed | |
| billing_interval | VARCHAR(20) | NOT NULL | monthly/annual |
| status | VARCHAR(50) | NOT NULL, indexed | active/past_due/canceled/trialing/etc. |
| current_period_start | TIMESTAMPTZ | NOT NULL | |
| current_period_end | TIMESTAMPTZ | NOT NULL | |
| cancel_at_period_end | BOOLEAN | default false | |
| canceled_at | TIMESTAMPTZ | nullable | |
| cancellation_reason | VARCHAR(255) | nullable | |
| trial_start | TIMESTAMPTZ | nullable | |
| trial_end | TIMESTAMPTZ | nullable | |
| stripe_metadata | JSONB | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `billing_details`

Company name, address, and tax information for invoices (1:1 with users).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, UNIQUE, NOT NULL, indexed | |
| company_name | VARCHAR(255) | nullable | |
| billing_email | VARCHAR(255) | nullable | |
| address_line1 | VARCHAR(255) | nullable | |
| address_line2 | VARCHAR(255) | nullable | |
| city | VARCHAR(100) | nullable | |
| state | VARCHAR(100) | nullable | |
| postal_code | VARCHAR(20) | nullable | |
| country | VARCHAR(2) | nullable | ISO 3166-1 alpha-2 |
| tax_id | VARCHAR(100) | nullable | |
| tax_id_type | VARCHAR(50) | nullable | eu_vat/us_ein |
| tax_exempt | BOOLEAN | default false | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `credit_packages`

Purchasable scan credit packages.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| name | VARCHAR(50) | NOT NULL | |
| credits | INTEGER | NOT NULL | |
| price_usd | NUMERIC(10,2) | NOT NULL | |
| discount_percent | INTEGER | NOT NULL, default 0 | |
| is_active | BOOLEAN | NOT NULL, default true | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `scan_credits`

User scan credit balance (1:1 with users).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, UNIQUE, NOT NULL, indexed | |
| balance | INTEGER | NOT NULL, default 0 | |
| total_purchased | INTEGER | NOT NULL, default 0 | |
| total_used | INTEGER | NOT NULL, default 0 | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `payment_transactions`

x402 payment transactions (USDC on Base).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE SET NULL, nullable, indexed | |
| payment_type | VARCHAR(20) | NOT NULL | per_scan/credits |
| amount_usd | NUMERIC(10,4) | NOT NULL | |
| token | VARCHAR(10) | NOT NULL, default 'USDC' | |
| network | VARCHAR(20) | NOT NULL, default 'base' | |
| tx_hash | VARCHAR(66) | nullable, indexed | |
| from_address | VARCHAR(42) | nullable | |
| to_address | VARCHAR(42) | nullable | |
| block_number | INTEGER | nullable | |
| x402_payment_id | VARCHAR(255) | nullable | |
| facilitator_response | JSONB | nullable | |
| status | VARCHAR(20) | NOT NULL, default 'pending', indexed | pending/verified/failed/refunded |
| verified_at | TIMESTAMPTZ | nullable | |
| credits_purchased | INTEGER | nullable | |
| package_id | UUID | FK credit_packages(id) ON DELETE SET NULL, nullable | |
| scan_id | UUID | FK scans(id) ON DELETE SET NULL, nullable | |
| receipt_number | VARCHAR(50) | UNIQUE, nullable, indexed | |
| created_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `credit_transactions`

Credit usage ledger (purchase, scan_usage, refund, gift).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| credits | INTEGER | NOT NULL | Positive for purchase, negative for usage |
| balance_after | INTEGER | NOT NULL | |
| transaction_type | VARCHAR(20) | NOT NULL, indexed | purchase/scan_usage/refund/gift |
| payment_transaction_id | UUID | FK payment_transactions(id) ON DELETE SET NULL, nullable | |
| scan_id | UUID | FK scans(id) ON DELETE SET NULL, nullable | |
| description | VARCHAR(255) | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |

### `stripe_event_log`

Webhook idempotency log (Migration 093, BSO-SEC-024). The Stripe webhook dispatcher does an `INSERT … ON CONFLICT (event_id) DO NOTHING RETURNING event_id` after signature verification. If 0 rows are returned, the event is a Stripe retry of an already-processed event → the dispatcher short-circuits with `HTTP 200 {received: true, duplicate: true}` and skips the handler.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| event_id | VARCHAR(255) | PRIMARY KEY | Stripe `event.id` (e.g. `evt_1NCqJU...`) |
| event_type | VARCHAR(100) | NOT NULL | Stripe `event.type` (e.g. `customer.subscription.updated`) |
| received_at | TIMESTAMPTZ | NOT NULL, default now() | When the webhook was first received and validated |
| processed_at | TIMESTAMPTZ | nullable | Stamped after the handler returns. NULL = in flight or crashed |

**Indexes:**
- `ix_stripe_event_log_type_received` on `(event_type, received_at)` — analytics + 30-day retention sweep

**Retention:** 30 days. Stripe never retries beyond ~3 days; the retention window is comfortable. Cleanup is handled by a separate Celery beat task (see api-service release notes).

### `ai_scan_metadata`

Per-AI-scan metadata (Migration 094, Phase 10 — BYO AI scanning). One row per scan whose `scanners_used` includes `'ai-anthropic'` (the catalog ID as of api-service v0.46.2; previously `'ai'` in Phase 1 initial ship). The primary-key FK to `scans(id)` gives a 1:1 relationship; `ON DELETE CASCADE` handles right-to-deletion cleanly (delete the scan → metadata goes with it).

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| scan_id | UUID | PRIMARY KEY, FK scans(id) ON DELETE CASCADE | 1:1 with `scans` |
| provider | VARCHAR(32) | NOT NULL, CHECK IN (anthropic, openai, gemini, bedrock-eu) | |
| provider_route | VARCHAR(16) | NOT NULL, CHECK IN (managed, byo) | `managed` uses Apogee's Anthropic key; `byo` uses `byo_llm_keys` |
| model_id | VARCHAR(64) | NOT NULL | e.g. `claude-sonnet-4-6`, `gpt-5`, `gemini-2.0-pro` |
| mode | VARCHAR(16) | NOT NULL, CHECK IN (structured, freeform) | |
| prompt_version | VARCHAR(32) | NOT NULL | e.g. `solidity/v1` — bumps when Apogee-owned prompts change |
| input_tokens | INTEGER | NOT NULL, >= 0 | actual consumed |
| output_tokens | INTEGER | NOT NULL, >= 0 | actual consumed |
| cost_usd_micros | BIGINT | NOT NULL default 0, >= 0 | per-scan cost in micro-USD (1e-6 USD) for billing reconciliation |
| sensitivity_acknowledged | BOOLEAN | NOT NULL default false | user acknowledged the contract sensitivity gate |
| byo_key_id | UUID | nullable, FK byo_llm_keys(id) ON DELETE SET NULL | NULL when route=managed |
| created_at | TIMESTAMPTZ | NOT NULL default now() | |

**Indexes:**
- `ix_ai_scan_metadata_created_at` on `(created_at)` — quota windowing + analytics
- `ix_ai_scan_metadata_provider_route` on `(provider, provider_route)` — per-provider cost reports

### `byo_llm_keys`

Encrypted at-rest BYO LLM API key storage (Migration 095, Phase 10). AES-256-GCM per `docs/standards/encryption-standards.md`; KEK held in Vault. Plaintext is **NEVER** persisted or logged; only `key_fingerprint` (last 4 plaintext chars + provider) is surfaced in the UI.

Scope is either organization-wide or user-personal — exactly one of `organization_id` / `user_id` is non-NULL, enforced by `ck_byo_llm_keys_exactly_one_scope`.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | UUID | PRIMARY KEY default gen_random_uuid() | |
| organization_id | UUID | nullable, FK organizations(id) ON DELETE CASCADE | NULL when user_id is set |
| user_id | UUID | nullable, FK users(id) ON DELETE CASCADE | NULL when organization_id is set |
| provider | VARCHAR(32) | NOT NULL, CHECK IN (anthropic, openai, gemini) | |
| key_label | VARCHAR(64) | NOT NULL | user-facing name e.g. "Engineering team OpenAI" |
| encrypted_key | BYTEA | NOT NULL | AES-256-GCM ciphertext |
| encryption_nonce | BYTEA | NOT NULL | 12 bytes, regenerated per encrypt |
| key_fingerprint | VARCHAR(64) | NOT NULL | last 4 chars of plaintext + provider (UI display ONLY) |
| validation_status | VARCHAR(16) | NOT NULL default 'unchecked', CHECK IN (valid, invalid, unchecked) | nightly cron re-validates active keys |
| validation_last_checked_at | TIMESTAMPTZ | nullable | |
| created_by | UUID | NOT NULL, FK users(id) ON DELETE RESTRICT | audit trail |
| created_at | TIMESTAMPTZ | NOT NULL default now() | |
| last_used_at | TIMESTAMPTZ | nullable | |
| revoked_at | TIMESTAMPTZ | nullable | soft-delete; preserves audit trail |

**Indexes (all partial, only on active keys):**
- `ix_byo_llm_keys_org_provider_active` on `(organization_id, provider)` UNIQUE WHERE `revoked_at IS NULL AND organization_id IS NOT NULL` — one active org key per provider
- `ix_byo_llm_keys_user_provider_active` on `(user_id, provider)` UNIQUE WHERE `revoked_at IS NULL AND user_id IS NOT NULL` — one active personal key per provider
- `ix_byo_llm_keys_validation_status` on `(validation_status)` WHERE `revoked_at IS NULL` — nightly re-validation sweep

---

## 5. Auth Domain: API Keys, Sessions, Tokens

### `sessions`

JWT session management.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | NOT NULL, indexed | |
| token | VARCHAR(500) | UNIQUE, NOT NULL, indexed | |
| refresh_token | VARCHAR(500) | UNIQUE, nullable, indexed | |
| expires_at | TIMESTAMPTZ | NOT NULL | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| is_revoked | BOOLEAN | default false | |

### `api_keys`

Programmatic API access keys with scoped permissions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE CASCADE, nullable, indexed | |
| name | VARCHAR(255) | NOT NULL | |
| key_prefix | VARCHAR(10) | NOT NULL, indexed | First 8 chars |
| key_hash | VARCHAR(255) | NOT NULL | SHA-256 |
| scopes | JSONB | NOT NULL, default '[]' | |
| rate_limit_per_minute | INTEGER | NOT NULL, default 60 | |
| rate_limit_per_hour | INTEGER | NOT NULL, default 1000 | |
| last_used_at | TIMESTAMPTZ | nullable | |
| total_requests | INTEGER | NOT NULL, default 0 | |
| expires_at | TIMESTAMPTZ | nullable | |
| is_active | BOOLEAN | NOT NULL, default true | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| revoked_at | TIMESTAMPTZ | nullable | |

### `ide_tokens`

Personal access tokens for VS Code and IntelliJ extensions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE SET NULL, nullable, indexed | |
| name | VARCHAR(255) | NOT NULL | |
| ide_type | VARCHAR(50) | NOT NULL, indexed | vscode/intellij |
| token_prefix | VARCHAR(16) | NOT NULL, indexed | |
| token_hash | VARCHAR(64) | NOT NULL | SHA-256 |
| permissions | JSONB | NOT NULL, default '["scan:create","scan:read"]' | |
| last_used_at | TIMESTAMPTZ | nullable | |
| last_used_ip | VARCHAR(45) | nullable | |
| total_scans | INTEGER | NOT NULL, default 0 | |
| expires_at | TIMESTAMPTZ | nullable | |
| is_active | BOOLEAN | NOT NULL, default true, indexed | |
| revoked_at | TIMESTAMPTZ | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `service_accounts`

Organization-level non-interactive accounts for CI/CD (Growth+ tier).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| organization_id | UUID | FK organizations(id) ON DELETE CASCADE, NOT NULL, indexed | |
| name | VARCHAR(255) | NOT NULL | |
| description | VARCHAR(500) | nullable | |
| created_by | UUID | FK users(id) ON DELETE SET NULL, NOT NULL, indexed | |
| key_prefix | VARCHAR(16) | NOT NULL, indexed | |
| key_hash | VARCHAR(64) | NOT NULL | SHA-256 |
| scopes | JSONB | NOT NULL, default '[]' | |
| rate_limit_per_minute | INTEGER | NOT NULL, default 120 | |
| rate_limit_per_hour | INTEGER | NOT NULL, default 2000 | |
| last_used_at | TIMESTAMPTZ | nullable | |
| last_used_ip | VARCHAR(45) | nullable | |
| total_requests | INTEGER | NOT NULL, default 0 | |
| expires_at | TIMESTAMPTZ | nullable | |
| is_active | BOOLEAN | NOT NULL, default true, indexed | |
| revoked_at | TIMESTAMPTZ | nullable | |
| revoked_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `admin_sessions`

MFA-verified admin sessions with IP binding and 30-minute inactivity timeout.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| session_token | VARCHAR(255) | UNIQUE, NOT NULL, indexed | |
| ip_address | VARCHAR(45) | NOT NULL | IPv6 max length |
| user_agent | VARCHAR(500) | nullable | |
| mfa_verified | BOOLEAN | NOT NULL, default false | |
| mfa_verified_at | TIMESTAMPTZ | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| expires_at | TIMESTAMPTZ | NOT NULL, indexed | Max 8h absolute duration |
| last_activity | TIMESTAMPTZ | NOT NULL, default now() | |
| is_revoked | BOOLEAN | NOT NULL, default false, indexed | |
| revoked_at | TIMESTAMPTZ | nullable | |
| revoked_reason | VARCHAR(255) | nullable | |

### `support_impersonation_sessions`

Tracks support staff impersonation of customer accounts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| admin_user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| customer_user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| reason | TEXT | NOT NULL | |
| started_at | TIMESTAMPTZ | NOT NULL, default now() | |
| ended_at | TIMESTAMPTZ | nullable | |
| expires_at | TIMESTAMPTZ | NOT NULL | |
| is_active | BOOLEAN | NOT NULL, default true, indexed | |
| actions_taken | JSONB | NOT NULL, default '[]' | |

---

## 6. Audit Domain: Audit Logs, Activity Logs

### `audit_logs`

General audit log for security and compliance.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE SET NULL, nullable, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE SET NULL, nullable, indexed | |
| action | VARCHAR(100) | NOT NULL, indexed | e.g., user.login, scan.create |
| resource_type | VARCHAR(50) | nullable, indexed | |
| resource_id | UUID | nullable, indexed | |
| ip_address | VARCHAR(45) | nullable | |
| user_agent | VARCHAR(500) | nullable | |
| request_id | VARCHAR(100) | nullable, indexed | |
| old_values | JSONB | nullable | |
| new_values | JSONB | nullable | |
| event_metadata | JSONB | nullable | |
| success | BOOLEAN | NOT NULL, default true | |
| error_message | TEXT | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |

### `admin_audit_logs`

Permanent audit log for admin actions (NEVER purged).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| admin_user_id | UUID | FK users(id) ON DELETE SET NULL, nullable, indexed | |
| admin_role | VARCHAR(50) | NOT NULL | Role at time of action |
| action | VARCHAR(100) | NOT NULL, indexed | |
| target_type | VARCHAR(50) | nullable, indexed | |
| target_id | UUID | nullable, indexed | |
| ip_address | VARCHAR(45) | NOT NULL | |
| user_agent | VARCHAR(500) | nullable | |
| request_id | VARCHAR(100) | nullable | |
| old_values | JSONB | nullable | |
| new_values | JSONB | nullable | |
| reason | TEXT | nullable | Required for destructive actions |
| success | BOOLEAN | NOT NULL, default true, indexed | |
| error_message | TEXT | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |

### `user_activity_logs`

Rolling user activity log (max 100 entries per user).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| activity_type | VARCHAR(50) | NOT NULL, indexed | file_upload/scan_started/payment/etc. |
| description | VARCHAR(500) | NOT NULL | |
| contract_id | UUID | FK contracts(id) ON DELETE SET NULL, nullable | |
| scan_id | UUID | FK scans(id) ON DELETE SET NULL, nullable | |
| scanner_type | VARCHAR(50) | nullable | |
| scan_status | VARCHAR(20) | nullable | |
| credits_used | INTEGER | NOT NULL, default 0 | |
| payment_amount | NUMERIC(10,2) | nullable | |
| payment_currency | VARCHAR(10) | nullable | |
| activity_metadata | JSONB | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |

**Indexes:** `ix_user_activity_logs_user_id_created_at` (user_id, created_at)

---

## 7. Collaboration Domain: Teams, Access, Comments

### `teams`

Teams within organizations.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| organization_id | UUID | FK organizations(id) ON DELETE CASCADE, NOT NULL, indexed | |
| name | VARCHAR(100) | NOT NULL | |
| slug | VARCHAR(100) | NOT NULL | |
| description | TEXT | nullable | |
| color | VARCHAR(7) | nullable | Hex color |
| is_default | BOOLEAN | NOT NULL, default false | |
| created_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_teams_org_slug` (organization_id, slug) UNIQUE

### `team_members`

Team membership (lead/member roles).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| team_id | UUID | FK teams(id) ON DELETE CASCADE, NOT NULL, indexed | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| role | VARCHAR(20) | NOT NULL, default 'member' | lead/member |
| added_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| added_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_team_members_unique` (team_id, user_id) UNIQUE

### `team_invites`

Team invitation tracking for onboarding and lead generation.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| inviter_user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE CASCADE, nullable, indexed | |
| team_id | UUID | FK teams(id) ON DELETE CASCADE, nullable, indexed | |
| email | VARCHAR(255) | NOT NULL, indexed | |
| name | VARCHAR(255) | nullable | |
| role | VARCHAR(50) | NOT NULL, default 'member' | |
| status | VARCHAR(20) | NOT NULL, default 'pending', indexed | pending/accepted/expired/revoked |
| invite_token | VARCHAR(64) | UNIQUE, NOT NULL, indexed | |
| expires_at | TIMESTAMPTZ | NOT NULL | |
| accepted_at | TIMESTAMPTZ | nullable | |
| accepted_by_user_id | UUID | FK users(id), nullable | |
| email_sent_at | TIMESTAMPTZ | nullable | |
| email_opened_at | TIMESTAMPTZ | nullable | |
| marketing_consent | BOOLEAN | NOT NULL, default false | GDPR |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `project_team_access`

Project access granted to teams.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| project_id | UUID | FK projects(id) ON DELETE CASCADE, NOT NULL, indexed | |
| team_id | UUID | FK teams(id) ON DELETE CASCADE, NOT NULL, indexed | |
| access_level | VARCHAR(20) | NOT NULL, default 'read' | owner/write/read |
| granted_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| granted_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_project_team_access_unique` (project_id, team_id) UNIQUE

### `project_user_access`

Direct project access for individual users.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| project_id | UUID | FK projects(id) ON DELETE CASCADE, NOT NULL, indexed | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| access_level | VARCHAR(20) | NOT NULL, default 'read' | owner/write/read |
| granted_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| granted_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_project_user_access_unique` (project_id, user_id) UNIQUE

### `vulnerability_assignments`

Vulnerability assignments to team members for remediation.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| vulnerability_id | UUID | FK vulnerabilities(id) ON DELETE CASCADE, NOT NULL, indexed | |
| assignee_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| assigned_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| status | VARCHAR(30) | NOT NULL, default 'open', indexed | open/in_progress/resolved/wont_fix/false_positive |
| priority | VARCHAR(20) | nullable | critical/high/medium/low |
| due_date | TIMESTAMPTZ | nullable | |
| notes | TEXT | nullable | |
| assigned_at | TIMESTAMPTZ | NOT NULL, default now() | |
| resolved_at | TIMESTAMPTZ | nullable | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_vuln_assignments_unique` (vulnerability_id, assignee_id) UNIQUE; `ix_vuln_assignments_status` (assignee_id, status)

### `vulnerability_annotations`

User annotations on vulnerabilities (false_positive, confirmed, etc.).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| vulnerability_id | UUID | FK vulnerabilities(id) ON DELETE CASCADE, NOT NULL, indexed | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| status | VARCHAR(50) | NOT NULL, indexed | |
| note | TEXT | nullable | |
| reason | VARCHAR(255) | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_vulnerability_annotations_unique` (vulnerability_id, user_id) UNIQUE

### `vulnerability_annotation_history`

Audit trail for annotation changes.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| annotation_id | UUID | FK vulnerability_annotations(id) ON DELETE CASCADE, NOT NULL, indexed | |
| user_id | UUID | FK users(id) ON DELETE SET NULL, nullable, indexed | |
| previous_status | VARCHAR(50) | nullable | |
| new_status | VARCHAR(50) | NOT NULL | |
| previous_note | TEXT | nullable | |
| new_note | TEXT | nullable | |
| change_reason | VARCHAR(255) | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |

### `comments`

Polymorphic comments on vulnerabilities, scans, contracts, and projects.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| entity_type | VARCHAR(30) | NOT NULL, indexed | vulnerability/scan/contract/project |
| entity_id | UUID | NOT NULL, indexed | |
| content | TEXT | NOT NULL | |
| mentions | JSONB | nullable, default '[]' | User IDs |
| parent_id | UUID | FK comments(id) ON DELETE CASCADE, nullable, indexed | Threading |
| is_edited | BOOLEAN | NOT NULL, default false | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_comments_entity` (entity_type, entity_id)

### `saved_searches`

User-saved search queries with JSONB parameters.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| name | VARCHAR(255) | NOT NULL | |
| description | TEXT | nullable | |
| search_params | JSONB | NOT NULL | |
| last_executed_at | TIMESTAMPTZ | nullable | |
| execution_count | INTEGER | NOT NULL, default 0 | |
| created_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `user_favorites`

Pinned items for quick dashboard access.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| item_type | VARCHAR(50) | NOT NULL, indexed | project/contract/scan |
| item_id | UUID | NOT NULL | |
| display_order | INTEGER | NOT NULL, default 0 | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_user_favorites_user_id_order` (user_id, display_order); `ix_user_favorites_unique` (user_id, item_type, item_id) UNIQUE

---

## 8. Notifications Domain: Webhooks, Channels

### `webhooks`

Webhook configurations for event notifications.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE CASCADE, nullable, indexed | |
| name | VARCHAR(255) | NOT NULL | |
| url | VARCHAR(2048) | NOT NULL | |
| secret | VARCHAR(255) | NOT NULL | HMAC-SHA256 signing |
| events | JSONB | NOT NULL | List of event types |
| is_active | BOOLEAN | NOT NULL, default true | |
| retry_count | INTEGER | NOT NULL, default 3 | |
| timeout_seconds | INTEGER | NOT NULL, default 30 | |
| total_deliveries | INTEGER | NOT NULL, default 0 | |
| successful_deliveries | INTEGER | NOT NULL, default 0 | |
| failed_deliveries | INTEGER | NOT NULL, default 0 | |
| last_triggered_at | TIMESTAMPTZ | nullable | |
| last_success_at | TIMESTAMPTZ | nullable | |
| last_failure_at | TIMESTAMPTZ | nullable | |
| last_error | TEXT | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `webhook_deliveries`

Webhook delivery audit log.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| webhook_id | UUID | FK webhooks(id) ON DELETE CASCADE, NOT NULL, indexed | |
| event_type | VARCHAR(50) | NOT NULL, indexed | |
| event_id | VARCHAR(100) | NOT NULL, indexed | |
| payload | JSONB | NOT NULL | |
| headers | JSONB | nullable | |
| status_code | INTEGER | nullable | |
| response_body | TEXT | nullable | |
| response_headers | JSONB | nullable | |
| attempt_number | INTEGER | NOT NULL, default 1 | |
| success | BOOLEAN | NOT NULL, default false | |
| error_message | TEXT | nullable | |
| duration_ms | INTEGER | nullable | |
| triggered_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |
| delivered_at | TIMESTAMPTZ | nullable | |

### `notification_channels`

Slack, Teams, Discord webhook integrations.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE CASCADE, nullable, indexed | |
| name | VARCHAR(255) | NOT NULL | |
| channel_type | VARCHAR(50) | NOT NULL, indexed | slack/teams/discord |
| webhook_url | VARCHAR(2048) | NOT NULL | |
| events | JSONB | NOT NULL | |
| filters | JSONB | nullable | |
| is_active | BOOLEAN | NOT NULL, default true, indexed | |
| total_notifications | INTEGER | NOT NULL, default 0 | |
| successful_notifications | INTEGER | NOT NULL, default 0 | |
| failed_notifications | INTEGER | NOT NULL, default 0 | |
| last_triggered_at | TIMESTAMPTZ | nullable | |
| last_success_at | TIMESTAMPTZ | nullable | |
| last_failure_at | TIMESTAMPTZ | nullable | |
| last_error | TEXT | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `notification_deliveries`

Notification delivery audit log.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| channel_id | UUID | FK notification_channels(id) ON DELETE CASCADE, NOT NULL, indexed | |
| event_type | VARCHAR(50) | NOT NULL, indexed | |
| event_id | VARCHAR(100) | NOT NULL | |
| payload | JSONB | NOT NULL | |
| status_code | INTEGER | nullable | |
| response_body | TEXT | nullable | |
| success | BOOLEAN | NOT NULL, default false | |
| error_message | TEXT | nullable | |
| duration_ms | INTEGER | nullable | |
| triggered_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |
| delivered_at | TIMESTAMPTZ | nullable | |

---

## 9. Integrations Domain: GitHub, GitLab, JIRA

### `integrations`

Third-party integration connections (OAuth).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| organization_id | UUID | FK organizations(id) ON DELETE CASCADE, NOT NULL, indexed | |
| provider | VARCHAR(50) | NOT NULL, indexed | github/gitlab/bitbucket/jira |
| name | VARCHAR(255) | NOT NULL | |
| status | VARCHAR(50) | NOT NULL, default 'pending', indexed | pending/connected/expired/error |
| external_account_id | VARCHAR(255) | nullable | |
| external_username | VARCHAR(255) | nullable | |
| external_avatar_url | VARCHAR(2048) | nullable | |
| jira_cloud_id | VARCHAR(255) | nullable | |
| jira_site_url | VARCHAR(2048) | nullable | |
| settings | JSONB | nullable, default '{}' | |
| repos_synced | INTEGER | NOT NULL, default 0 | |
| last_sync_at | TIMESTAMPTZ | nullable | |
| last_error | TEXT | nullable | |
| created_by | UUID | FK users(id) ON DELETE SET NULL, nullable, indexed | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_integrations_org_provider_unique` (organization_id, provider) UNIQUE

### `integration_credentials`

Encrypted credentials for integrations (OAuth + GitHub App BYO). Stores either
OAuth tokens (GitLab/Bitbucket/JIRA) or GitHub App fields (migration 087),
never both on the same row.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| integration_id | UUID | FK integrations(id) ON DELETE CASCADE, UNIQUE, NOT NULL, indexed | |
| access_token_encrypted | TEXT | nullable (since 087) | OAuth access token; NULL for GitHub App BYO rows |
| refresh_token_encrypted | TEXT | nullable | |
| token_type | VARCHAR(50) | NOT NULL, default 'Bearer' | |
| scopes | JSONB | nullable | |
| expires_at | TIMESTAMPTZ | nullable | |
| github_app_id | VARCHAR(20) | nullable (087) | GitHub-assigned numeric App ID |
| github_app_slug | VARCHAR(255) | nullable (087) | URL slug `github.com/apps/{slug}` |
| github_app_client_id | VARCHAR(255) | nullable (087) | OAuth client ID for the App |
| github_app_private_key_encrypted | TEXT | nullable (087) | Fernet-encrypted PEM; signs RS256 app JWTs |
| github_app_webhook_secret_encrypted | TEXT | nullable (087) | Fernet-encrypted HMAC secret |
| github_app_installation_id | BIGINT | nullable (087) | Set after customer completes install step |
| github_app_created_at | TIMESTAMPTZ | nullable (087) | When manifest exchange finished |
| github_app_installed_at | TIMESTAMPTZ | nullable (087) | When installation_id was recorded |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `integration_repositories`

Connected Git repositories from external providers.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| integration_id | UUID | FK integrations(id) ON DELETE CASCADE, NOT NULL, indexed | |
| project_id | UUID | FK projects(id) ON DELETE SET NULL, nullable, indexed | |
| external_repo_id | VARCHAR(255) | NOT NULL, indexed | |
| repo_name | VARCHAR(255) | NOT NULL | |
| repo_full_name | VARCHAR(500) | NOT NULL | owner/repo |
| repo_url | VARCHAR(2048) | NOT NULL | |
| default_branch | VARCHAR(255) | nullable, default 'main' | |
| is_private | BOOLEAN | NOT NULL, default false | |
| auto_scan_enabled | BOOLEAN | NOT NULL, default false | |
| scan_on_push | BOOLEAN | NOT NULL, default true | |
| scan_on_pr | BOOLEAN | NOT NULL, default true | |
| last_synced_at | TIMESTAMPTZ | nullable | |
| last_synced_commit | VARCHAR(40) | nullable | |
| contracts_found | INTEGER | NOT NULL, default 0 | |
| sync_status | VARCHAR(50) | NOT NULL, default 'pending' | pending/syncing/synced/error |
| sync_error | TEXT | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_integration_repositories_unique` (integration_id, external_repo_id) UNIQUE

### `jira_project_mappings`

Links Apogee projects to JIRA projects.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| integration_id | UUID | FK integrations(id) ON DELETE CASCADE, NOT NULL, indexed | |
| blocksecops_project_id | UUID | FK projects(id) ON DELETE CASCADE, NOT NULL, indexed | |
| jira_project_id | VARCHAR(255) | NOT NULL | |
| jira_project_key | VARCHAR(50) | NOT NULL | |
| jira_project_name | VARCHAR(255) | NOT NULL | |
| issue_type | VARCHAR(100) | NOT NULL, default 'Bug' | |
| auto_create_issues | BOOLEAN | NOT NULL, default true | |
| min_severity_to_sync | VARCHAR(20) | NOT NULL, default 'medium' | |
| field_mappings | JSONB | nullable, default '{}' | |
| issues_created | INTEGER | NOT NULL, default 0 | |
| last_sync_at | TIMESTAMPTZ | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_jira_project_mappings_unique` (integration_id, jira_project_id) UNIQUE

### `jira_issue_syncs`

Vulnerability-to-JIRA issue sync tracking.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| mapping_id | UUID | FK jira_project_mappings(id) ON DELETE CASCADE, NOT NULL, indexed | |
| vulnerability_id | UUID | FK vulnerabilities(id) ON DELETE CASCADE, NOT NULL, indexed | |
| jira_issue_id | VARCHAR(255) | NOT NULL | |
| jira_issue_key | VARCHAR(50) | NOT NULL, indexed | e.g., PROJ-123 |
| jira_issue_url | VARCHAR(2048) | NOT NULL | |
| jira_status | VARCHAR(100) | nullable | |
| last_synced_at | TIMESTAMPTZ | nullable | |
| sync_direction | VARCHAR(20) | NOT NULL, default 'outbound' | outbound/inbound/bidirectional |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_jira_issue_syncs_unique` (mapping_id, vulnerability_id) UNIQUE

---

## 10. AI/Copilot Domain: Conversations, Repairs, Reviews, Invariants

### `copilot_conversations`

AI Security Copilot conversation sessions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| scan_id | UUID | FK scans(id) ON DELETE SET NULL, nullable, indexed | |
| project_id | UUID | FK projects(id) ON DELETE SET NULL, nullable, indexed | |
| title | VARCHAR(255) | NOT NULL | |
| summary | TEXT | nullable | |
| is_archived | BOOLEAN | default false | |
| message_count | INTEGER | default 0 | |
| total_tokens | INTEGER | default 0 | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |

### `copilot_messages`

Individual messages within copilot conversations.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| conversation_id | UUID | FK copilot_conversations(id) ON DELETE CASCADE, NOT NULL, indexed | |
| role | VARCHAR(20) | NOT NULL | user/assistant/system |
| content | TEXT | NOT NULL | |
| context_sources | JSONB | nullable | RAG context used |
| tokens_input | INTEGER | default 0 | |
| tokens_output | INTEGER | default 0 | |
| model_used | VARCHAR(100) | nullable | |
| generation_time_ms | INTEGER | nullable | |
| rating | INTEGER | nullable | |
| feedback_text | TEXT | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |

### `repair_suggestions`

AI-generated code repair suggestions for vulnerabilities.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| vulnerability_id | UUID | FK vulnerabilities(id) ON DELETE CASCADE, NOT NULL, indexed | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| original_code | TEXT | NOT NULL | |
| file_path | VARCHAR(500) | nullable | |
| start_line | INTEGER | nullable | |
| end_line | INTEGER | nullable | |
| fixed_code | TEXT | NOT NULL | |
| diff_patch | TEXT | NOT NULL | |
| explanation | TEXT | NOT NULL | |
| fix_type | VARCHAR(50) | NOT NULL | |
| confidence | FLOAT | NOT NULL, default 0.0 | |
| model_used | VARCHAR(100) | NOT NULL | |
| tokens_input | INTEGER | NOT NULL, default 0 | |
| tokens_output | INTEGER | NOT NULL, default 0 | |
| generation_time_ms | INTEGER | nullable | |
| was_applied | BOOLEAN | default false | |
| applied_at | TIMESTAMPTZ | nullable | |
| rating | INTEGER | nullable | 1-5 |
| feedback_text | TEXT | nullable | |
| was_helpful | BOOLEAN | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |

### `review_suggestions`

AI-generated code review suggestions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| vulnerability_id | UUID | FK vulnerabilities(id) ON DELETE CASCADE, NOT NULL, indexed | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| suggestion_text | TEXT | NOT NULL | |
| risk_explanation | TEXT | nullable | |
| attack_scenario | TEXT | nullable | |
| recommended_fix | TEXT | nullable | |
| code_context | TEXT | nullable | |
| model_used | VARCHAR(100) | NOT NULL | |
| tokens_input | INTEGER | NOT NULL, default 0 | |
| tokens_output | INTEGER | NOT NULL, default 0 | |
| generation_time_ms | INTEGER | nullable | |
| is_cached | BOOLEAN | default false | |
| created_at | TIMESTAMPTZ | NOT NULL | |

### `review_feedback`

User feedback on code review suggestions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| suggestion_id | UUID | FK review_suggestions(id) ON DELETE CASCADE, NOT NULL, indexed | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| rating | INTEGER | NOT NULL | 1-5 |
| was_helpful | BOOLEAN | NOT NULL | |
| was_applied | BOOLEAN | nullable | |
| feedback_text | TEXT | nullable | |
| accuracy_rating | INTEGER | nullable | 1-5 |
| clarity_rating | INTEGER | nullable | 1-5 |
| usefulness_rating | INTEGER | nullable | 1-5 |
| created_at | TIMESTAMPTZ | NOT NULL | |

### `poc_exploits`

AI-generated proof-of-concept exploit code.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| vulnerability_id | UUID | FK vulnerabilities(id) ON DELETE CASCADE, NOT NULL, indexed | |
| exploit_code | TEXT | NOT NULL | |
| setup_code | TEXT | nullable | |
| test_code | TEXT | nullable | |
| explanation | TEXT | nullable | |
| attack_vector | VARCHAR(100) | nullable | |
| preconditions | TEXT | nullable | |
| impact_assessment | TEXT | nullable | |
| contract_code | TEXT | nullable | |
| vulnerability_description | TEXT | nullable | |
| model_used | VARCHAR(100) | NOT NULL | |
| tokens_input | INTEGER | NOT NULL, default 0 | |
| tokens_output | INTEGER | NOT NULL, default 0 | |
| generation_time_ms | INTEGER | nullable | |
| confidence | FLOAT | NOT NULL, default 0.0 | |
| safety_validated | BOOLEAN | default false | |
| safety_warnings | JSON | nullable | |
| disclaimer_included | BOOLEAN | default true | |
| rating | INTEGER | nullable | |
| feedback_text | TEXT | nullable | |
| was_helpful | BOOLEAN | nullable | |
| was_accurate | BOOLEAN | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, indexed | |
| updated_at | TIMESTAMPTZ | NOT NULL | |

### `invariants`

AI-generated Foundry invariants for smart contracts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| contract_id | UUID | FK contracts(id) ON DELETE CASCADE, NOT NULL, indexed | |
| invariant_code | TEXT | NOT NULL | |
| invariant_type | VARCHAR(50) | NOT NULL | state/access/arithmetic/economic |
| function_name | VARCHAR(200) | nullable | |
| description | TEXT | nullable | |
| model_used | VARCHAR(100) | NOT NULL | |
| tokens_input | INTEGER | NOT NULL, default 0 | |
| tokens_output | INTEGER | NOT NULL, default 0 | |
| generation_time_ms | INTEGER | nullable | |
| confidence | FLOAT | NOT NULL, default 0.0 | |
| was_applied | BOOLEAN | default false | |
| applied_at | TIMESTAMPTZ | nullable | |
| rating | INTEGER | nullable | 1-5 |
| feedback_text | TEXT | nullable | |
| was_helpful | BOOLEAN | nullable | |
| syntax_valid | BOOLEAN | nullable | |
| validation_error | TEXT | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |

### `invariant_templates`

Reusable invariant templates for common patterns.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| name | VARCHAR(200) | UNIQUE, NOT NULL | |
| description | TEXT | nullable | |
| template_code | TEXT | NOT NULL | |
| invariant_type | VARCHAR(50) | NOT NULL | |
| applicable_patterns | JSON | nullable | |
| keywords | JSON | nullable | |
| usage_count | INTEGER | NOT NULL, default 0 | |
| is_active | BOOLEAN | NOT NULL, default true | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |

---

## 11. Monitoring Domain: Monitored Contracts, Alerts

### `monitored_contracts`

On-chain contract monitoring configuration.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE SET NULL, nullable, indexed | |
| address | VARCHAR(42) | NOT NULL, indexed | Contract address |
| chain | VARCHAR(50) | NOT NULL, indexed | ethereum/bsc/polygon |
| name | VARCHAR(200) | nullable | |
| abi | JSONB | nullable | |
| monitored_functions | VARCHAR[] | nullable | |
| alert_threshold_usd | NUMERIC(20,2) | nullable, default 10000 | |
| is_active | BOOLEAN | NOT NULL, default true | |
| webhook_url | TEXT | nullable | |
| webhook_secret | VARCHAR(100) | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |
| updated_at | TIMESTAMPTZ | NOT NULL | |
| last_checked_block | INTEGER | nullable | |

### `alerts`

Runtime security alerts for monitored contracts.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| contract_id | UUID | FK monitored_contracts(id) ON DELETE CASCADE, NOT NULL, indexed | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| alert_type | VARCHAR(50) | NOT NULL, indexed | large_transfer/ownership_change/etc. |
| severity | VARCHAR(20) | NOT NULL, indexed | |
| title | VARCHAR(500) | NOT NULL | |
| description | TEXT | nullable | |
| tx_hash | VARCHAR(66) | nullable, indexed | |
| block_number | INTEGER | nullable | |
| from_address | VARCHAR(42) | nullable | |
| to_address | VARCHAR(42) | nullable | |
| value_wei | VARCHAR(78) | nullable | uint256 max |
| value_usd | NUMERIC(20,2) | nullable | |
| details | JSONB | nullable | |
| function_called | VARCHAR(200) | nullable | |
| acknowledged | BOOLEAN | NOT NULL, default false | |
| acknowledged_at | TIMESTAMPTZ | nullable | |
| acknowledged_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| webhook_sent | BOOLEAN | NOT NULL, default false | |
| webhook_sent_at | TIMESTAMPTZ | nullable | |
| detected_at | TIMESTAMPTZ | NOT NULL, indexed | |
| created_at | TIMESTAMPTZ | NOT NULL | |

---

## 12. Scanner Results Domain: Quality, Gas, Fuzzing, Formal Verification

### `quality_gates`

CI/CD quality gate configurations.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| project_id | UUID | FK projects(id) ON DELETE CASCADE, nullable, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE CASCADE, nullable, indexed | |
| name | VARCHAR(255) | NOT NULL | |
| description | TEXT | nullable | |
| block_on_critical | BOOLEAN | NOT NULL, default true | |
| block_on_high | BOOLEAN | NOT NULL, default false | |
| block_on_medium | BOOLEAN | NOT NULL, default false | |
| block_on_low | BOOLEAN | NOT NULL, default false | |
| max_critical | INTEGER | NOT NULL, default 0 | 0 = any blocks, -1 = disabled |
| max_high | INTEGER | NOT NULL, default -1 | |
| max_medium | INTEGER | NOT NULL, default -1 | |
| max_low | INTEGER | NOT NULL, default -1 | |
| advanced_rules | JSONB | nullable | |
| is_active | BOOLEAN | NOT NULL, default true | |
| enforce_on_pr | BOOLEAN | NOT NULL, default true | |
| enforce_on_main | BOOLEAN | NOT NULL, default true | |
| notify_on_failure | BOOLEAN | NOT NULL, default true | |
| notification_channels | JSONB | nullable | |
| created_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_quality_gates_project_active` (project_id, is_active); `ix_quality_gates_org_active` (organization_id, is_active)

### `quality_gate_evaluations`

Quality gate evaluation audit trail.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| quality_gate_id | UUID | FK quality_gates(id) ON DELETE CASCADE, NOT NULL, indexed | |
| scan_id | UUID | FK scans(id) ON DELETE CASCADE, NOT NULL, indexed | |
| project_id | UUID | FK projects(id) ON DELETE CASCADE, NOT NULL, indexed | |
| passed | BOOLEAN | NOT NULL | |
| status | VARCHAR(20) | NOT NULL | passing/failing/warning/skipped |
| critical_count | INTEGER | NOT NULL, default 0 | |
| high_count | INTEGER | NOT NULL, default 0 | |
| medium_count | INTEGER | NOT NULL, default 0 | |
| low_count | INTEGER | NOT NULL, default 0 | |
| violations | JSONB | nullable | |
| triggered_by | VARCHAR(50) | nullable | manual/ci/scheduled |
| ci_context | JSONB | nullable | {branch, commit, pr} |
| evaluated_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:** `ix_qg_evaluations_scan_date` (scan_id, evaluated_at); `ix_qg_evaluations_project_date` (project_id, evaluated_at)

### `code_quality_findings`

Code quality findings from linters and static analysis.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| scan_id | UUID | FK scans(id) ON DELETE CASCADE, NOT NULL | |
| scanner_id | VARCHAR(50) | NOT NULL | |
| severity | VARCHAR(20) | NOT NULL | warning/info/suggestion |
| category | VARCHAR(50) | NOT NULL | best-practices/style/maintainability/security |
| title | TEXT | NOT NULL | |
| description | TEXT | NOT NULL | |
| location | JSONB | NOT NULL | {file, line, column, end_line, end_column} |
| fix_suggestion | TEXT | nullable | |
| rule_id | VARCHAR(100) | NOT NULL | |
| rule_url | TEXT | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |

### `gas_analysis_findings`

Gas optimization findings.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| scan_id | UUID | FK scans(id) ON DELETE CASCADE, NOT NULL | |
| scanner_id | VARCHAR(50) | NOT NULL | |
| function_name | VARCHAR(255) | NOT NULL | |
| gas_cost | INTEGER | NOT NULL | |
| optimization_level | VARCHAR(20) | NOT NULL | critical/high/medium/low |
| optimization_suggestion | TEXT | NOT NULL | |
| potential_savings | INTEGER | NOT NULL | Gas units |
| location | JSONB | NOT NULL | |
| code_example | TEXT | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |

### `formal_verification_results`

Formal verification results from proof tools.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| scan_id | UUID | FK scans(id) ON DELETE CASCADE, NOT NULL | |
| scanner_id | VARCHAR(50) | NOT NULL | |
| property_name | VARCHAR(255) | NOT NULL | |
| status | VARCHAR(20) | NOT NULL | proven/failed/timeout/unknown |
| proof_type | VARCHAR(50) | NOT NULL | invariant/assertion/property |
| description | TEXT | NOT NULL | |
| counterexample | TEXT | nullable | |
| verification_time | FLOAT | NOT NULL | Seconds |
| created_at | TIMESTAMPTZ | NOT NULL | |

### `fuzzing_results`

Fuzzing test results.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| scan_id | UUID | FK scans(id) ON DELETE CASCADE, NOT NULL | |
| scanner_id | VARCHAR(50) | NOT NULL | |
| test_name | VARCHAR(255) | NOT NULL | |
| status | VARCHAR(20) | NOT NULL | passed/failed/error |
| executions | INTEGER | NOT NULL | |
| coverage_percentage | FLOAT | NOT NULL | |
| edge_cases_found | JSONB | NOT NULL, default '[]' | |
| failure_trace | TEXT | nullable | |
| seed | INTEGER | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL | |

### `scanner_versions`

Persistent snapshot of scanner metadata seeded from the `scanner-versions` ConfigMap on api-service startup. Added 2026-03-17 in migration 085. Used by `GET /api/v1/scanners` and the admin scanner management endpoints.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | SERIAL | PRIMARY KEY | |
| scanner_name | VARCHAR(100) | NOT NULL, UNIQUE | Canonical scanner ID (e.g. `slither`, `mythril`). Constraint: `UNIQUE(scanner_name)`. |
| scanner_type | VARCHAR(50) | NOT NULL, CHECK | One of `static-analysis`, `fuzzer`, `formal-verification`, `linting`, `symbolic-execution`. |
| ecosystem | VARCHAR(50) | NOT NULL, CHECK | One of `evm`, `solana`, `move`, `multi`. |
| language | VARCHAR(50) | NOT NULL | Target language (e.g. `solidity`, `vyper`, `move`). |
| current_version | VARCHAR(50) | NOT NULL | Upstream tool version currently deployed (e.g. `0.11.5`). |
| latest_version | VARCHAR(50) | nullable | Latest available upstream release; populated by version-check CronJob. |
| version_status | VARCHAR(20) | NOT NULL, default `up-to-date`, CHECK | One of `up-to-date`, `outdated`, `unknown`, `deprecated`. |
| image_tag | VARCHAR(50) | nullable | Apogee scanner image tag (e.g. `0.3.2`). |
| image_name | VARCHAR(200) | nullable | Full image reference including registry path. |
| developer | VARCHAR(200) | nullable | Third-party developer / maintainer name. |
| repository_url | TEXT | nullable | Upstream source repository URL. |
| detector_count | INTEGER | NOT NULL, default 0 | Total detectors available in the upstream tool. |
| integrated_detector_count | INTEGER | NOT NULL, default 0 | Detectors actively wired into Apogee's pipeline. |
| last_checked_at | TIMESTAMPTZ | nullable | When the version-check CronJob last ran for this scanner. |
| last_updated_at | TIMESTAMPTZ | NOT NULL, default now() | When this row was last modified. |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | When the row was first seeded. |
| notes | TEXT | nullable | Admin-visible changelog / notes from the ConfigMap `_note` field. |

**Indexes:**
- `idx_scanner_versions_ecosystem` — `(ecosystem)`
- `idx_scanner_versions_type` — `(scanner_type)`
- `idx_scanner_versions_status` — `(version_status)`

**Check constraints:**
- `valid_version_status` — closed-set CHECK on `version_status`
- `valid_scanner_type` — closed-set CHECK on `scanner_type`
- `valid_ecosystem` — closed-set CHECK on `ecosystem`

---

### `scanner_version_history`

Audit trail of every admin scanner upgrade + rollback + auto-revert. Added 2026-04-15 in migration 086 as fix #3 of the admin scanner upgrade pipeline review. Used by `POST /api/v1/admin/system/scanners/{name}/rollback` to resolve the immediately-prior version.

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | SERIAL | PRIMARY KEY | |
| scanner_name | VARCHAR(100) | NOT NULL | Matches `scanner_versions.scanner_name` but no FK (history must survive scanner deletion) |
| previous_version | VARCHAR(50) | NOT NULL | Version the ConfigMap held before this operation |
| new_version | VARCHAR(50) | NOT NULL | Version the operation applied (or rolled back to) |
| state | VARCHAR(40) | NOT NULL, CHECK | One of `applied` / `reverted` / `applied_db_stale` / `tool_integration_failed` / `rejected` (fix #5 outcome vocabulary) |
| reason | TEXT | nullable | Admin-supplied rationale; sanitized via `sanitize_user_text` at the API boundary |
| admin_user_id | UUID | FK users(id) ON DELETE SET NULL, nullable | Admin who triggered the operation |
| upgrade_source | VARCHAR(20) | NOT NULL, default `admin_portal`, CHECK | One of `admin_portal` / `rollback` / `auto_revert` (routing hint for the rollback query) |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

**Indexes:**
- `idx_scanner_version_history_scanner_time` — `(scanner_name, created_at DESC)` — rollback target lookup
- `idx_scanner_version_history_admin` — `(admin_user_id, created_at DESC)` — per-admin audit queries

**Check constraints:**
- `valid_upgrade_state` — closed-set CHECK on `state`
- `valid_upgrade_source` — closed-set CHECK on `upgrade_source`

---

## 13. ML/Compliance Domain: Consent, Provenance, GDPR

### `tos_consent_records`

Terms of Service consent tracking (GDPR/LGPD compliance).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| tos_version | VARCHAR(20) | NOT NULL | |
| privacy_policy_version | VARCHAR(20) | NOT NULL | |
| ml_data_collection_consent | BOOLEAN | NOT NULL, default true | |
| consent_ip_address | VARCHAR(45) | nullable | |
| consent_user_agent | TEXT | nullable | |
| consented_at | TIMESTAMPTZ | NOT NULL, default now() | |
| withdrawn_at | TIMESTAMPTZ | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `ml_training_data_provenance`

ML training data lineage for compliance and right-to-deletion.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| vulnerability_id | UUID | FK vulnerabilities(id) ON DELETE CASCADE, NOT NULL, indexed | |
| organization_id | UUID | FK organizations(id) ON DELETE SET NULL, nullable, indexed | |
| user_id | UUID | FK users(id) ON DELETE SET NULL, NOT NULL, indexed | |
| label | VARCHAR(20) | NOT NULL | confirmed/false_positive |
| confidence | FLOAT | nullable | |
| features_snapshot | JSONB | NOT NULL | Anonymized, no PII |
| tos_consent_id | UUID | FK tos_consent_records(id) ON DELETE SET NULL, nullable | |
| consent_version | VARCHAR(20) | NOT NULL | |
| excluded_from_training | BOOLEAN | NOT NULL, default false, indexed | |
| exclusion_reason | VARCHAR(50) | nullable | org_opt_out/user_withdrawn/pre_consent |
| collected_at | TIMESTAMPTZ | NOT NULL, default now() | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `gdpr_data_requests`

GDPR/LGPD data export and deletion requests.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| request_type | VARCHAR(20) | NOT NULL, indexed | export/deletion |
| status | VARCHAR(20) | NOT NULL, default 'pending', indexed | pending/processing/completed/failed |
| requester_email | VARCHAR(255) | NOT NULL | |
| processed_at | TIMESTAMPTZ | nullable | |
| processed_by | UUID | nullable | |
| export_file_path | VARCHAR(500) | nullable | |
| export_expires_at | TIMESTAMPTZ | nullable | |
| deletion_confirmed_at | TIMESTAMPTZ | nullable | |
| error_message | TEXT | nullable | |
| request_ip_address | VARCHAR(45) | nullable | |
| request_user_agent | TEXT | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

---

## 14. Platform Domain: Settings, Referrals, Feedback, Support

### `platform_settings`

Admin-configurable platform-wide settings (key-value store).

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| key | VARCHAR(100) | PK | |
| value | TEXT | NOT NULL | |
| description | VARCHAR(500) | nullable | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_by | UUID | FK users(id) ON DELETE SET NULL, nullable | |

### `referrals`

Tracks individual referral completions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| referrer_user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| referred_user_id | UUID | FK users(id) ON DELETE SET NULL, nullable, indexed | |
| referral_code | VARCHAR(20) | NOT NULL, indexed | |
| status | VARCHAR(20) | NOT NULL, default 'completed' | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| completed_at | TIMESTAMPTZ | nullable | |

### `referral_rewards`

Rewards earned from referral completions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| referrer_user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| reward_type | VARCHAR(50) | NOT NULL, default 'free_month' | |
| plan_tier | VARCHAR(50) | NOT NULL, default 'starter' | |
| status | VARCHAR(20) | NOT NULL, default 'pending' | |
| qualifying_referral_count | INTEGER | NOT NULL | |
| applied_at | TIMESTAMPTZ | nullable | |
| expires_at | TIMESTAMPTZ | nullable | |
| stripe_coupon_id | VARCHAR(255) | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `user_feedback`

General user feedback submissions.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| category | VARCHAR(50) | NOT NULL, indexed | bug/feature/general/other |
| subject | VARCHAR(255) | NOT NULL | |
| message | TEXT | NOT NULL | |
| contact_email | VARCHAR(255) | nullable | |
| status | VARCHAR(20) | NOT NULL, default 'pending', indexed | pending/reviewed/resolved/dismissed |
| page_url | VARCHAR(500) | nullable | |
| user_agent | VARCHAR(500) | nullable | |
| created_at | TIMESTAMPTZ | NOT NULL, default now() | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

### `support_tickets`

Support ticket submissions with JIRA integration.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | UUID | PK | |
| user_id | UUID | FK users(id) ON DELETE CASCADE, NOT NULL, indexed | |
| category | VARCHAR(50) | NOT NULL, indexed | bug/billing/feature_request/security/general |
| priority | VARCHAR(20) | NOT NULL, default 'medium' | low/medium/high/urgent |
| subject | VARCHAR(255) | NOT NULL | |
| description | TEXT | NOT NULL | |
| user_email | VARCHAR(255) | NOT NULL | |
| user_tier | VARCHAR(20) | NOT NULL | |
| page_url | VARCHAR(500) | nullable | |
| user_agent | VARCHAR(500) | nullable | |
| jira_issue_key | VARCHAR(50) | nullable, indexed | |
| jira_issue_url | VARCHAR(2048) | nullable | |
| jira_sync_status | VARCHAR(20) | NOT NULL, default 'pending' | pending/synced/failed/disabled |
| status | VARCHAR(20) | NOT NULL, default 'open', indexed | open/in_progress/resolved/closed |
| ticket_number | INTEGER | nullable, UNIQUE indexed | Migration 083. Human-readable sequential reference (e.g. BSO-0001). Backfilled by created_at order. Index `ix_support_tickets_ticket_number` (unique). |
| organization_id | UUID | FK organizations(id) ON DELETE SET NULL, nullable, indexed | Migration 084. Scopes ticket to an org. Index `ix_support_tickets_organization_id`. |
| created_at | TIMESTAMPTZ | NOT NULL, default now(), indexed | |
| updated_at | TIMESTAMPTZ | NOT NULL, default now() | |

---

## 15. ENUM Types

| Name | Values | Used By |
|------|--------|---------|
| `contract_language` | solidity, vyper, rust, move, cairo, tact, clarity, yul, huff, fe, simplicity, michelson, plutus, sway, cadence, motoko, ink, zinc, leo, near, cosmos | contracts.language |
| `contract_status` | uploaded, pending, scanning, scanned, failed | contracts.status |
| `scan_status` | queued, running, completed, failed, cancelled | scans.status |
| `vulnerability_severity` | critical, high, medium, low | vulnerabilities.severity |
| `vulnerability_status` | open, acknowledged, fixed, false_positive | vulnerabilities.status |

**Note:** User tier values (developer, starter, growth, enterprise) are enforced via CHECK constraint on `users.tier` and `user_quotas.tier`, not an ENUM type.

---

## 16. Trigger Functions

### `create_user_quota()`

**Type:** BEFORE INSERT trigger on `users` table
**Language:** PL/pgSQL

Automatically creates a `user_quotas` row with tier-appropriate limits when a new user is inserted. Quota values align with `tiers.json` v4.0 (Migration 081 - competitive pricing adjustment):

| Quota | Developer | Starter | Growth | Enterprise |
|-------|-----------|---------|--------|------------|
| monthly_scan_limit | 3 | 25 | 75 | -1 (unlimited) |
| max_projects | 3 | 15 | -1 | -1 |
| max_team_members | 2 | 5 | 25 | -1 |
| result_retention_days | 7 | 90 | 365 | 365 |
| monthly_ai_explanations_limit | 0 | 75 | 300 | -1 |
| concurrent_scans_limit | 1 | 2 | 5 | -1 |
| web_requests_per_minute | 60 | 120 | 300 | -1 |
| api_requests_per_minute | 0 | 0 | 300 | -1 |
| api_requests_per_hour | 0 | 0 | 10000 | -1 |
| export_enabled | false | true | true | true |
| api_access_enabled | false | false | true | true |
| webhooks_enabled | false | true | true | true |
| scan_priority | 50 | 40 | 25 | 5 |

---

*Generated from ORM models at `/home/pwner/Git/blocksecops-api-service/src/infrastructure/database/models.py` and `/home/pwner/Git/blocksecops-api-service/src/infrastructure/database/specialized_models/`. Last migration applied: 096 (2026-06-20). Table count 99 verified against prod DB 2026-06-21.*
