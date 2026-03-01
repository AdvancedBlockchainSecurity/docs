# AI Invariant Generation Database Schema

## Overview

Phase E introduces AI-powered Foundry invariant generation for smart contracts. This feature stores generated invariants, reusable templates, and tracks user quota usage.

## Tables

### `invariants`

Stores AI-generated Foundry invariants for smart contracts.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `id` | UUID | No | Primary key |
| `user_id` | UUID | No | FK to users.id (CASCADE delete) |
| `contract_id` | UUID | No | FK to contracts.id (CASCADE delete) |
| `invariant_code` | TEXT | No | Generated Solidity invariant code |
| `invariant_type` | VARCHAR(50) | No | Type: state, access, arithmetic, economic, reentrancy |
| `function_name` | VARCHAR(200) | Yes | Target function (optional) |
| `description` | TEXT | Yes | Human-readable description |
| `model_used` | VARCHAR(100) | No | Claude model used (e.g., claude-sonnet-4-6) |
| `tokens_input` | INTEGER | No | Input tokens consumed |
| `tokens_output` | INTEGER | No | Output tokens generated |
| `generation_time_ms` | INTEGER | Yes | Generation time in milliseconds |
| `confidence` | FLOAT | No | AI confidence score (0.0-1.0) |
| `was_applied` | BOOLEAN | No | Whether invariant was applied to contract |
| `applied_at` | TIMESTAMP | Yes | When invariant was applied |
| `rating` | INTEGER | Yes | User rating (1-5 stars) |
| `feedback_text` | TEXT | Yes | User feedback comment |
| `was_helpful` | BOOLEAN | Yes | Was this invariant helpful? |
| `syntax_valid` | BOOLEAN | Yes | Syntax validation result |
| `validation_error` | TEXT | Yes | Validation error message if any |
| `created_at` | TIMESTAMP | No | Creation timestamp |
| `updated_at` | TIMESTAMP | No | Last update timestamp |

**Indexes:**
- `idx_invariants_user_contract` - (user_id, contract_id)
- `idx_invariants_type` - (invariant_type)
- `idx_invariants_created_at` - (created_at)

### `invariant_templates`

Reusable invariant templates for common patterns.

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `id` | UUID | No | Primary key |
| `name` | VARCHAR(200) | No | Unique template name |
| `description` | TEXT | Yes | Template description |
| `template_code` | TEXT | No | Solidity template code |
| `invariant_type` | VARCHAR(50) | No | Type: state, access, arithmetic, economic |
| `applicable_patterns` | JSON | Yes | Vulnerability patterns this applies to |
| `keywords` | JSON | Yes | Keywords for matching |
| `usage_count` | INTEGER | No | Times this template was used |
| `is_active` | BOOLEAN | No | Whether template is active |
| `created_at` | TIMESTAMP | No | Creation timestamp |
| `updated_at` | TIMESTAMP | No | Last update timestamp |

**Indexes:**
- `idx_invariant_templates_type` - (invariant_type)
- `idx_invariant_templates_active` - (is_active)

**Default Templates:**
1. `balance_consistency` - Ensures total supply equals sum of balances
2. `no_zero_address_owner` - Ensures owner is never zero address
3. `reentrancy_lock` - Validates reentrancy guard state
4. `arithmetic_no_overflow` - Checks for arithmetic overflow
5. `pause_halts_transfers` - Validates pause functionality

### `user_quotas` (Extended)

New columns added for invariant quota tracking:

| Column | Type | Nullable | Description |
|--------|------|----------|-------------|
| `invariant_daily_used` | INTEGER | No | Invariants generated today (default: 0) |
| `invariant_last_generated_at` | TIMESTAMP | Yes | Last generation time (for cooldown) |
| `invariant_daily_reset_at` | TIMESTAMP | Yes | Next daily quota reset time |

## Tier Quotas

| Tier | Monthly Limit | Daily Cap | Cooldown |
|------|---------------|-----------|----------|
| Developer | 0 (blocked) | - | - |
| Team | 10 | 10 | 5 seconds |
| Growth | 50 | 50 | 5 seconds |
| Enterprise | Unlimited | 500 | 5 seconds |

## Migration

Migration: `059_add_invariant_tables`

```bash
# Run migration
kubectl exec deployment/api-service -n api-service-local -- alembic upgrade head

# Rollback
kubectl exec deployment/api-service -n api-service-local -- alembic downgrade 058_add_audit_log_protection
```

## Related Documentation

- [AI Invariant Testing Guide](../feature-tests/AI-INVARIANT-TESTING.md)
- [AI Features API](../api/ai-features.md)
- [ML Fields Overview](./ML-FIELDS.md)
