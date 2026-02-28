# Apogee Database Schema (Minimal Reference)

**Database:** PostgreSQL 15.4 | **Name:** `solidity_security` | **Schema:** `public`

**Connection:** `postgresql+asyncpg://postgres:postgres@127.0.0.1:5432/solidity_security`

---

## Tables (49 total)

### Core Tables

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `users` | `id` UUID | `email`, `supabase_user_id`, `tier`, `wallet_address` | 1:N contracts, scans, projects |
| `contracts` | `id` UUID | `user_id` FK, `name`, `language`, `status`, `source_code` | N:1 users, 1:N scans/vulnerabilities |
| `contract_files` | `id` UUID | `contract_id` FK, `file_path`, `file_content`, `is_main_file` | N:1 contracts |
| `scans` | `id` UUID | `contract_id` FK, `user_id` FK, `status`, `priority`, `scanners_used[]` | N:1 contracts/users, 1:N vulnerabilities |
| `vulnerabilities` | `id` UUID | `scan_id` FK, `contract_id` FK, `severity`, `status`, `scanner_id`, `pattern_id` | N:1 scans/contracts |

### Project Organization

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `projects` | `id` UUID | `user_id` FK, `name`, `settings` JSONB | N:1 users, M:N contracts |
| `project_contracts` | `(project_id, contract_id)` | `added_at` | Junction table |

### User Management

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `user_quotas` | `id` UUID | `user_id` FK UNIQUE, `tier`, `monthly_scan_limit`, `monthly_scans_used` | 1:1 users |
| `user_preferences` | `user_id` UUID | `email_notifications`, `theme`, `timezone` | 1:1 users |
| `user_activity_logs` | `id` UUID | `user_id` FK, `activity_type`, `credits_used` | N:1 users |
| `user_favorites` | `id` UUID | `user_id` FK, `item_type`, `item_id` | N:1 users |
| `saved_searches` | `id` UUID | `user_id` FK, `name`, `search_params` JSONB | N:1 users |

### Intelligence Layer

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `vulnerability_patterns` | `id` VARCHAR(50) | `name`, `category`, `severity`, `swc_id`, `cwe_id`, `affected_languages[]` | 1:N pattern_tool_mappings |
| `pattern_tool_mappings` | `id` UUID | `pattern_id` FK, `scanner_id`, `detector_id` | N:1 vulnerability_patterns |
| `deduplication_groups` | `id` UUID | `canonical_finding_id` FK, `pattern_code`, `group_size`, `strategy` | 1:N vulnerabilities |

### Specialized Results

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `gas_analysis_findings` | `id` UUID | `scan_id` FK, `scanner_id`, `function_name`, `gas_cost`, `potential_savings` | N:1 scans |
| `code_quality_findings` | `id` UUID | `scan_id` FK, `scanner_id`, `severity`, `rule_id` | N:1 scans |
| `fuzzing_results` | `id` UUID | `scan_id` FK, `scanner_id`, `test_name`, `status`, `coverage_percentage` | N:1 scans |
| `formal_verification_results` | `id` UUID | `scan_id` FK, `scanner_id`, `property_name`, `status`, `proof_type` | N:1 scans |

### Contract Analysis

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `contract_functions` | `id` UUID | `contract_id` FK, `name`, `selector`, `visibility`, `state_mutability` | N:1 contracts |
| `contract_events` | `id` UUID | `contract_id` FK, `name`, `topic0`, `parameters` JSONB | N:1 contracts |
| `contract_state_variables` | `id` UUID | `contract_id` FK, `name`, `type_name`, `visibility`, `storage_slot` | N:1 contracts |

### Annotations & Collaboration

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `vulnerability_annotations` | `id` UUID | `vulnerability_id` FK, `user_id` FK, `status`, `note` | N:1 vulnerabilities/users |
| `vulnerability_annotation_history` | `id` UUID | `annotation_id` FK, `previous_status`, `new_status` | N:1 annotations |
| `vulnerability_assignments` | `id` UUID | `vulnerability_id` FK, `assignee_id` FK, `status`, `priority`, `due_date` | N:1 vulnerabilities/users |
| `comments` | `id` UUID | `user_id` FK, `entity_type`, `entity_id`, `content`, `parent_id` | Polymorphic |
| `scan_batches` | `id` UUID | `user_id` FK, `project_id` FK, `total_contracts`, `status` | N:1 users/projects |

### Enterprise Features

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `organizations` | `id` UUID | `name`, `slug` UNIQUE, `tier`, `sso_enabled`, `owner_id` FK | 1:N members/roles |
| `roles` | `id` UUID | `organization_id` FK, `name`, `permissions` JSONB, `is_system_role` | N:1 organizations |
| `organization_members` | `id` UUID | `organization_id` FK, `user_id` FK, `role_id` FK | N:1 orgs/users/roles |
| `teams` | `id` UUID | `organization_id` FK, `name`, `slug` | N:1 organizations |
| `team_members` | `id` UUID | `team_id` FK, `user_id` FK, `role` | N:1 teams/users |
| `team_invites` | `id` UUID | `inviter_user_id` FK, `email`, `status`, `invite_token` UNIQUE | N:1 users/orgs/teams |
| `project_team_access` | `id` UUID | `project_id` FK, `team_id` FK, `access_level` | N:1 projects/teams |
| `project_user_access` | `id` UUID | `project_id` FK, `user_id` FK, `access_level` | N:1 projects/users |

### Webhooks & Notifications

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `webhooks` | `id` UUID | `user_id` FK, `name`, `url`, `secret`, `events` JSONB, `is_active` | N:1 users/orgs |
| `webhook_deliveries` | `id` UUID | `webhook_id` FK, `event_type`, `payload` JSONB, `success` | N:1 webhooks |
| `notification_channels` | `id` UUID | `user_id` FK, `channel_type` (slack/teams/discord), `webhook_url`, `events` JSONB | N:1 users/orgs |
| `notification_deliveries` | `id` UUID | `channel_id` FK, `event_type`, `payload` JSONB, `success` | N:1 channels |

### API & Audit

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `api_keys` | `id` UUID | `user_id` FK, `key_prefix`, `key_hash`, `scopes` JSONB, `is_active` | N:1 users/orgs |
| `audit_logs` | `id` UUID | `user_id` FK, `action`, `resource_type`, `resource_id`, `old_values` JSONB | N:1 users/orgs |

### Payments & Credits

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `credit_packages` | `id` UUID | `name`, `credits`, `price_usd`, `is_active` | 1:N transactions |
| `scan_credits` | `id` UUID | `user_id` FK UNIQUE, `balance`, `total_purchased`, `total_used` | 1:1 users |
| `payment_transactions` | `id` UUID | `user_id` FK, `payment_type`, `amount_usd`, `tx_hash`, `status` | N:1 users/packages |
| `credit_transactions` | `id` UUID | `user_id` FK, `credits`, `balance_after`, `transaction_type` | N:1 users |

### Quality Gates (CI/CD)

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `quality_gates` | `id` UUID | `project_id` FK, `name`, `block_on_critical`, `max_critical`, `is_active` | N:1 projects/orgs |
| `quality_gate_evaluations` | `id` UUID | `quality_gate_id` FK, `scan_id` FK, `passed`, `violations` JSONB | N:1 gates/scans |

### ML Models

| Table | Primary Key | Key Columns | Relationships |
|-------|-------------|-------------|---------------|
| `ml_model_metadata` | `id` INTEGER | `model_name` UNIQUE, `current_version`, `labels_since_train`, `accuracy` | Standalone |

---

## ENUM Types

| Type | Values |
|------|--------|
| `contract_language` | solidity, vyper, rust, move, cairo, tact, clarity, yul, huff, fe, + more |
| `contract_status` | uploaded, pending, scanning, scanned, failed |
| `scan_status` | queued, running, completed, failed |
| `vulnerability_severity` | critical, high, medium, low (lowercase required) |
| `vulnerability_status` | open, acknowledged, fixed, false_positive |

---

## Key Relationships

**Cascade Delete:**
- `contract_files` → `contracts`
- `scans` → `contracts` (vulnerabilities cascade with scans)
- `project_contracts` → `projects`, `contracts`
- `user_quotas`, `user_preferences` → `users`
- All org/team membership → parent entities

**Set Null on Delete:**
- `payment_transactions.scan_id` (preserve billing history)
- `audit_logs.user_id` (preserve audit trail)

---

## Tier Limits (4-Tier Model)

| Tier | Price | Scans/Mo | Files | LoC | Projects | API Calls |
|------|-------|----------|-------|-----|----------|-----------|
| Developer | $0 | 10 | 5 | 5K | 3 | 0 |
| Team | $299 | 100 | Unlim | Unlim | 10 | 1K |
| Growth | $699 | 500 | Unlim | Unlim | 20 | 10K |
| Enterprise | $1,999+ | Unlim | Unlim | Unlim | Unlim | Unlim |

---

## Pattern Distribution (352 patterns)

- **Solidity/EVM:** 171 patterns (BVD-EVM-*)
- **Vyper:** 99 patterns (BVD-VYPER-*)
- **Solana/Rust:** 82 patterns (BVD-SOLANA-*)
- **Cairo/StarkNet:** 14 patterns (BVD-CAIRO-*)

**Scanner Coverage:** 12 scanners, 397 detector mappings (100%)

---

## Common Queries

```sql
-- User's contracts
SELECT * FROM contracts WHERE user_id = $1;

-- Scan vulnerabilities by severity
SELECT * FROM vulnerabilities
WHERE scan_id = $1
ORDER BY severity, detected_at DESC;

-- User quota check
SELECT * FROM user_quotas WHERE user_id = $1;

-- Deduplicated findings for a scan
SELECT v.* FROM vulnerabilities v
WHERE v.scan_id = $1 AND v.is_primary = true;
```

---

*Full schema: [SCHEMA.md](./SCHEMA.md)*
