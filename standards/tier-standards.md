# Tier Standards - Source of Truth

**Last Updated**: February 28, 2026
**Version**: 3.5 (Integrations tier gate update, IDE token tier fix)
**Status**: Official
**Owner**: Product Team

This document describes the tier and pricing standards for the Apogee platform.

## Centralized Configuration

**The actual source of truth is now `blocksecops-shared/tier-config/tiers.json`.**

All tier values (quotas, features, pricing, rate limits) are defined in that JSON file and consumed by:
- **Python backend**: `blocksecops-tier-config` package
- **TypeScript frontend**: `@blocksecops/tier-config` package

This document serves as **human-readable documentation** of those values. When values differ, `tiers.json` is authoritative.

---

## Tier Hierarchy

```
developer (0) < team (1) < growth (2) < enterprise (3)
```

**Tier Names** (official, use these exact strings in API/database):
- `developer` (Free tier)
- `team`
- `growth`
- `enterprise`

---

## Subscription Tiers

### Tier 1: Developer (Free)

| Attribute | Value |
|-----------|-------|
| **Price** | $0 (forever) |
| **Monthly Contracts** | 3 |
| **Max LoC per Scan** | Unlimited |
| **Max Files per Scan** | Unlimited |
| **Projects** | 3 |
| **Team Members** | 2 |
| **API Calls/Month** | 0 (no API access) |
| **Result Retention** | 7 days |
| **Scan Priority** | 50 (lowest) |
| **API Access** | No |
| **Private Repos** | No (public only) |
| **Multi-Chain** | No (Solidity only) |
| **Continuous Monitoring** | No |
| **95% FP Reduction** | No |
| **Webhooks** | No |
| **Export Reports** | Yes (PDF, JSON, SARIF) |
| **AI Explanations/Month** | 0 |
| **AI Invariant Generations/Month** | 0 |
| **Scanners** | All 25+ |
| **Support** | Community |

**Best For**: Platform trials, evaluating the product, open-source developers

**Restrictions**:
- Public repositories only
- No ML-powered false positive filtering
- No API access
- Community support only

---

### Tier 2: Team

| Attribute | Value |
|-----------|-------|
| **Price** | $299/month (~$2,988/year with 17% discount) |
| **Monthly Contracts** | 15 |
| **Max LoC per Scan** | Unlimited |
| **Max Files per Scan** | Unlimited |
| **Projects** | 10 |
| **Team Members** | 5 |
| **API Calls/Month** | 0 (no API access) |
| **Result Retention** | 90 days |
| **Scan Priority** | 40 |
| **API Access** | No |
| **Private Repos** | 3 |
| **Multi-Chain** | No (Solidity only) |
| **Continuous Monitoring** | No |
| **95% FP Reduction** | Yes |
| **Webhooks** | Yes |
| **CI/CD Integration** | Yes |
| **Export Reports** | Yes (PDF, JSON, SARIF) |
| **AI Explanations/Month** | 50 |
| **AI Invariant Generations/Month** | 10 |
| **Scanners** | All 25+ |
| **Support** | Email (24h response) |

**Best For**: Small development teams, freelance auditors, early-stage startups
**Per-Contract Cost**: $19.93

---

### Tier 3: Growth

| Attribute | Value |
|-----------|-------|
| **Price** | $699/month (~$7,188/year with 17% discount) |
| **Monthly Contracts** | 50 |
| **Max LoC per Scan** | Unlimited |
| **Max Files per Scan** | Unlimited |
| **Projects** | Unlimited (-1) |
| **Team Members** | 15 |
| **API Calls/Month** | Unlimited (-1) |
| **Result Retention** | 180 days |
| **Scan Priority** | 25 |
| **API Access** | Yes |
| **Private Repos** | Unlimited |
| **Multi-Chain** | Yes (Solidity, Vyper, Rust/Solana, Cairo, Move) |
| **Continuous Monitoring** | Yes |
| **95% FP Reduction** | Yes |
| **Webhooks** | Yes |
| **CI/CD Integration** | Yes |
| **Export Reports** | Yes (PDF, JSON, SARIF) |
| **AI Explanations/Month** | 200 |
| **AI Invariant Generations/Month** | 50 |
| **Scanners** | All 25+ |
| **Support** | Priority (4h response) |

**Best For**: Growing protocols, multi-chain projects, companies preparing for audits
**Per-Contract Cost**: $13.98

---

### Tier 4: Enterprise

| Attribute | Value |
|-----------|-------|
| **Price** | $1,999+/month (custom pricing) |
| **Monthly Contracts** | Unlimited (-1) |
| **Max LoC per Scan** | Unlimited (-1) |
| **Max Files per Scan** | Unlimited (-1) |
| **Projects** | Unlimited (-1) |
| **Team Members** | Unlimited (-1) |
| **API Calls/Month** | Unlimited (-1) |
| **Result Retention** | 365 days |
| **Scan Priority** | 5 (highest) |
| **API Access** | Yes |
| **Private Repos** | Unlimited |
| **Multi-Chain** | Yes |
| **Continuous Monitoring** | Yes |
| **95% FP Reduction** | Yes |
| **Webhooks** | Yes |
| **CI/CD Integration** | Yes |
| **Organizations** | Yes |
| **Audit Logs** | Yes |
| **SSO/SAML** | Yes |
| **SLA Guarantee** | 99.9% |
| **Export Reports** | Yes (PDF, JSON, SARIF) |
| **AI Explanations/Month** | Unlimited (-1) |
| **AI Invariant Generations/Month** | Unlimited (-1) |
| **AI Priority Queue** | Yes |
| **Custom AI Prompts** | Available |
| **Scanners** | All 25+ |
| **Support** | Dedicated (named contact) |

**Best For**: Large organizations, major DeFi protocols, companies requiring compliance

---

## Quick Reference Table

### Quota Limits

| Metric | Developer | Team | Growth | Enterprise |
|--------|-----------|------|--------|------------|
| Monthly Contracts | 3 | 15 | 50 | -1 |
| Max LoC per Scan | -1 | -1 | -1 | -1 |
| Max Files per Scan | -1 | -1 | -1 | -1 |
| Projects | 3 | 10 | -1 | -1 |
| Team Members | 2 | 5 | 15 | -1 |
| API Calls/Month | 0 | 0 | -1 | -1 |
| Private Repos | 0 | 3 | -1 | -1 |
| AI Explanations/Month | 0 | 50 | 200 | -1 |
| AI Invariant Gens/Month | 0 | 10 | 50 | -1 |
| Result Retention (days) | 7 | 90 | 180 | 365 |
| Scan Priority | 50 | 40 | 25 | 5 |

**Note**: `-1` means unlimited

### Feature Availability

| Feature | Developer | Team | Growth | Enterprise |
|---------|-----------|------|--------|------------|
| All 25+ Scanners | Yes | Yes | Yes | Yes |
| Export Reports | Yes | Yes | Yes | Yes |
| 95% FP Reduction | No | Yes | Yes | Yes |
| Private Repos | No | 3 | Unlimited | Unlimited |
| API Access | No | No | Yes | Yes |
| Webhooks | No | Yes | Yes | Yes |
| CI/CD Integration | Yes | Yes | Yes | Yes |
| Multi-Chain Support | No | No | Yes | Yes |
| Continuous Monitoring | No | No | Yes | Yes |
| AI Explanations | No | Yes | Yes | Yes |
| AI Invariants | No | Yes | Yes | Yes |
| AI Priority Queue | No | No | No | Yes |
| Organizations | No | No | No | Yes |
| Audit Logs | No | No | No | Yes |
| SSO/SAML | No | No | No | Yes |
| SLA Guarantee | No | No | No | 99.9% |

### Pricing

| Tier | Monthly | Annual | Savings | Per-Contract |
|------|---------|--------|---------|--------------|
| Developer | $0 | $0 | - | - |
| Team | $299 | ~$2,988 | 17% | $19.93 |
| Growth | $699 | ~$7,188 | 17% | $13.98 |
| Enterprise | $1,999+ | Custom | - | ~$0 |

### Price Multipliers

| Tier Jump | Multiplier |
|-----------|------------|
| Team → Growth | 2.3x |
| Growth → Enterprise | 2.9x |

### Support Levels

| Tier | Support Type | Response Time |
|------|--------------|---------------|
| Developer | Community | Best effort |
| Team | Email | 24 hours |
| Growth | Priority | 4 hours |
| Enterprise | Dedicated | Named contact |

---

## Rate Limits

### API Access Availability

**Key Change:** API access is only available on Growth and Enterprise tiers.

| Tier | API Access |
|------|------------|
| Developer | No |
| Team | No |
| Growth | Yes |
| Enterprise | Yes |

### API Rate Limits (Growth+ Only)

| Tier | Requests/Min | Requests/Hour | Requests/Day |
|------|--------------|---------------|--------------|
| Developer | N/A | N/A | N/A |
| Team | N/A | N/A | N/A |
| Growth | 300 | 10,000 | Unlimited |
| Enterprise | Custom | Custom | Custom |

**Note:** Developer and Team tiers have no API access. Use the dashboard or CI/CD integrations instead.

### Dashboard/CI Rate Limits (All Tiers)

| Tier | Web Requests/Min | Concurrent Scans | Scan Priority |
|------|------------------|------------------|---------------|
| Developer | 60 | 1 | 50 (lowest) |
| Team | 120 | 2 | 40 |
| Growth | 300 | 5 | 25 |
| Enterprise | Custom | Custom | 5 (highest) |

### Concurrent Scan Limits

| Tier | Concurrent Scans |
|------|------------------|
| Developer | 1 |
| Team | 2 |
| Growth | 5 |
| Enterprise | Custom |

---

## AI Features (Claude Integration)

**Status**: ACTIVE (v0.28.2)
**Added**: January 11, 2026
**Deployed**: February 7, 2026

AI-powered features use the Anthropic Claude API and are tier-gated with monthly quotas. Most AI endpoints require Team tier or above (`require_tier("team")`). PoC Exploit Generation requires Growth tier or above (`require_tier("growth")`).

### AI Feature Overview

| Feature | Endpoint Prefix | Model | Max Tokens | Cost/Request |
|---------|-----------------|-------|------------|--------------|
| **AI Copilot** | `/copilot/` | Claude Sonnet 4 | 2,048 | ~$0.03-0.09 |
| **Code Review** | `/review/` | Claude Haiku 3.5 | 2,048 | ~$0.012 |
| **Code Repair** | `/code-repair/` | Claude Sonnet 4 | 4,096 | ~$0.06-0.15 |
| **Invariant Generation** | `/invariants/` | Claude Sonnet 4 | 4,096 | ~$0.09 |
| **Economic Analysis** | `/economic-analysis/` | Claude Haiku 3.5 | N/A | ~$0.012 |
| **PoC Exploit Generation** | `/exploits/` | Claude Sonnet 4 | 8,192 | ~$0.09-0.18 |

### AI Quota Summary (Monthly)

| Feature | Developer | Team | Growth | Enterprise |
|---------|-----------|------|--------|------------|
| AI Copilot queries | 0 | 25 | 100 | -1 |
| Code Review requests | 0 | 25 | 100 | -1 |
| Code Repair requests | 0 | 10 | 50 | -1 |
| Invariant Generations | 0 | 10 | 50 | -1 |
| PoC Exploit Generations | 0 | 0 | 5 | 50 |
| AI Explanations | 0 | 50 | 200 | -1 |
| NL Conversions | 0 | 25 | 100 | -1 |
| Priority Queue | No | No | No | Yes |

**Note:** `-1` means unlimited. Enterprise has a daily cap of 500 invariant generations and 100 exploit generations to prevent runaway usage. PoC exploit generation requires Growth+ tier (Developer/Team blocked) due to its security-sensitive nature.

### AI Rate Limits

| Control | Value | Scope |
|---------|-------|-------|
| Global per-user rate | 20 req/min | All AI endpoints combined |
| Per-feature rate limit | Tier-based via `get_rate_limit_string("ai", <feature>)` | Individual features |
| Invariant cooldown | 5 seconds between requests | Invariant generation only |
| Exploit cooldown | 10 seconds between requests | PoC exploit generation only |

### Security Controls

| Control | Implementation | Audit Finding |
|---------|----------------|---------------|
| Input sanitization | `_sanitize_for_prompt()`: truncation, HTML escape, control char removal | BSO-SEC-AI-001 |
| Output validation | `_validate_ai_output()`: injection pattern detection | BSO-SEC-AI-002 |
| XML boundary isolation | User content in `<retrieved_context>` tags | BSO-SEC-AI-001 |
| Error sanitization | `get_safe_error_detail()` on all AI error responses | BSO-SEC-LOG-003 |
| Token budget | Per-request output caps + budget warnings | BSO-SEC-LOW-005 |
| Exploit output safety | `_validate_output_safety()`: reject selfdestruct, private keys, broadcast flags | BSO-SEC-AI-003 |

### Feature Flags

| Flag | Default | Scope |
|------|---------|-------|
| `ai_features_enabled` | `true` | Master toggle (disables all AI) |
| `ai_copilot_enabled` | `true` | Copilot only |
| `ai_code_review_enabled` | `true` | Code review only |
| `ai_code_repair_enabled` | `true` | Code repair only |
| `ai_invariant_enabled` | `true` | Invariant generation only |

### Claude API Pricing (February 2026)

| Model | Input (per MTok) | Output (per MTok) | Used By |
|-------|------------------|-------------------|---------|
| Claude Haiku 3.5 | $0.80 | $4.00 | Code Review, Economic Analysis |
| Claude Sonnet 4 | $3.00 | $15.00 | Copilot, Code Repair, Invariants |

### Monthly Cost to Apogee (Absorbed in Tier)

| Tier | Typical AI Usage | Est. Monthly Cost |
|------|------------------|-------------------|
| Developer | 0 | $0 |
| Team | ~120 requests (mixed models) | ~$3-5 |
| Growth | ~500 requests (mixed models) | ~$15-25 |
| Enterprise | Variable | Usage-based billing |

### Implementation

**Vault Secret Path**: `secret/local/api-service/anthropic` (property: `api_key`)

**K8s Secret Flow**: Vault → ExternalSecret → `api-service-secret` → `ANTHROPIC_API_KEY` env var

**Configuration** (`src/infrastructure/config.py`):
```python
anthropic_api_key: Optional[str]                     # From Vault
anthropic_model_copilot: str = "claude-sonnet-4-6"
anthropic_model_code_review: str = "claude-haiku-4-5-20251001"
anthropic_model_code_repair: str = "claude-sonnet-4-6"
anthropic_model_invariant: str = "claude-sonnet-4-6"
anthropic_rate_limit_per_minute: int = 20
anthropic_max_tokens_copilot: int = 2048
anthropic_max_tokens_code_review: int = 2048
anthropic_max_tokens_code_repair: int = 4096
anthropic_max_tokens_invariant: int = 4096
```

**Tier Gating Pattern** (all AI generation endpoints):
```python
@router.post("/generate")
async def generate(
    current_user=Depends(require_tier("team")),  # Developer blocked
    ...
):
```

### Related AI Documentation

- [AI Features Workflow](../workflows/ai-features-workflow.md) — End-to-end workflow
- [AI Copilot Pipeline](../pipelines/ai-copilot-pipeline.md) — Copilot details
- [AI Code Review Pipeline](../pipelines/ai-code-review-pipeline.md) — Code review details
- [AI Code Repair Pipeline](../pipelines/ai-code-repair-pipeline.md) — Code repair details
- [AI Invariant Pipeline](../pipelines/ai-invariant-generation-pipeline.md) — Invariant details
- [AI Economic Analysis Pipeline](../pipelines/ai-economic-analysis-pipeline.md) — Economic analysis details

---

## Pay-Per-Scan (x402) Credits

**Status**: FINALIZED (January 2026)

Pay-per-scan credit packages via x402 (USDC on Base) for users who prefer flexible billing over subscriptions.

### Credit Packages

| Package | Credits | Price (USDC) | Per-Credit | Savings |
|---------|---------|--------------|------------|---------|
| **Starter** | 10 | $30 | $3.00 | - |
| **Builder** | 50 | $125 | $2.50 | 17% |
| **Pro** | 200 | $400 | $2.00 | 33% |
| **Bulk** | 1,000 | $1,500 | $1.50 | 50% |

**Note**: 1 credit = 1 scan. Credits never expire.

### Premium Add-Ons

| Add-On | Price | Description |
|--------|-------|-------------|
| **Express Scan** | $99/scan | 4-hour turnaround |
| **Formal Verification** | $299/contract | Add formal verification |
| **Audit Report** | $149/report | Professional audit report |
| **Extra Contracts** | $19/contract | Over tier limit |
| **Extra Users** | $29/user/month | Over tier limit |

### Competitive Analysis

| Platform | Model | Per-Scan Cost | Scanners |
|----------|-------|---------------|----------|
| Apogee x402 | Credit packages | $1.50-$3.00 | 25+ |
| MythX On-Demand | Per-scan | $3.33 | 1 |
| SolidityScan On-Demand | LoC-based | $15-30 | 1 |

**Value Proposition**: "Same price as MythX, get 25x the scanners"

### Subscription Break-Even

| x402 Usage (Starter) | x402 Cost | Better Option |
|----------------------|-----------|---------------|
| 5 scans/month | $15 | x402 (Starter) |
| 10 scans/month | $30 | x402 (Starter) |
| 15+ scans/month | $45+ | Team ($299) |

### Environment Variables

```bash
# x402 credit packages (USDC)
CREDIT_PACKAGE_STARTER_PRICE=30.00
CREDIT_PACKAGE_STARTER_CREDITS=10
CREDIT_PACKAGE_BUILDER_PRICE=125.00
CREDIT_PACKAGE_BUILDER_CREDITS=50
CREDIT_PACKAGE_PRO_PRICE=400.00
CREDIT_PACKAGE_PRO_CREDITS=200
CREDIT_PACKAGE_BULK_PRICE=1500.00
CREDIT_PACKAGE_BULK_CREDITS=1000
```

---

## API Endpoint Tier Gates

All premium API endpoints are protected by `require_tier()` dependencies. Core endpoints (scans, contracts, vulnerabilities) are accessible to all authenticated users regardless of tier.

**Note:** Developer and Team tiers also have `api_access_enabled=false` in `user_quotas`, which causes the `APICallTrackerMiddleware` to return 429 before the tier gate is even reached. The tier gate provides defense-in-depth for tiers with API access.

| Endpoint | Required Tier | Blocked Tiers |
|----------|--------------|---------------|
| `POST /api/v1/search` | team | developer |
| `GET /api/v1/api-keys` | growth | developer, team |
| `GET /api/v1/integrations` | team | developer |
| `GET /api/v1/notification-channels` | growth | developer, team |
| `GET /api/v1/webhooks` | growth | developer, team |
| `GET /api/v1/audit-logs` | growth | developer, team |
| `POST /api/v1/organizations` | enterprise | developer, team, growth |
| `PUT /api/v1/organizations/{id}/settings/ai-opt-out` | enterprise | developer, team, growth |
| `POST /api/v1/economic-analysis/reports` | enterprise | developer, team, growth |
| `POST /api/v1/economic-analysis/simulate` | enterprise | developer, team, growth |
| `POST /api/v1/ide-tokens` | growth | developer, team |
| AI generation endpoints | team | developer |
| PoC exploit generation | growth | developer, team |

**Regression tests:** 22 structural tests in `tests/unit/presentation/test_tier_gate_enforcement.py` verify these gates at the source level.

---

## Implementation Reference

### Centralized Tier Config Package

**Location**: `blocksecops-shared/tier-config/`

| File | Purpose |
|------|---------|
| `tiers.json` | **THE SOURCE OF TRUTH** - all tier values |
| `python/blocksecops_tier_config/` | Python package for backend |
| `typescript/` | TypeScript package for frontend |

**Usage**:
```python
# Python (backend)
from blocksecops_tier_config import get_tier, get_tier_quotas_for_db, VALID_TIERS
```

```typescript
// TypeScript (frontend)
import { getTier, TIER_HIERARCHY, VALID_TIERS } from '@blocksecops/tier-config';
```

### Source Files That Must Match These Standards

| Component | File Path | What to Update |
|-----------|-----------|----------------|
| **Tier Config** | `blocksecops-shared/tier-config/tiers.json` | **Primary source - update here first** |
| Website | `~/Git/Platform-websites/blocksecops_com/app/(frontend)/pricing/page.tsx` | `pricingTiers` array |
| Dashboard | `/blocksecops-dashboard/src/pages/Pricing.tsx` | Pricing display |
| DB Trigger | `alembic/versions/20260103_0100-024_tier_restructure.py` | `create_user_quota()` function |
| Stripe Service | `/blocksecops-api-service/src/application/services/stripe_service.py` | `PLAN_LIMITS` dict, price IDs |
| Pricing Service | `/blocksecops-api-service/src/application/services/pricing_service.py` | `ScanComplexity`, `prices` dict, LoC limits |
| User Schema | `/blocksecops-api-service/src/presentation/schemas/users.py` | `QuotaInfo.tier` description |
| AI Quota Migration | `alembic/versions/YYYYMMDD-033_ai_quota_columns.py` | AI quota columns (TO BE CREATED) |
| AI Quota Middleware | `/blocksecops-api-service/src/infrastructure/auth/ai_quota.py` | `@require_ai_quota` decorator (TO BE CREATED) |
| Economic AI Explainer | `/blocksecops-api-service/src/services/economic_ai_explainer.py` | AI explanation service (TO BE CREATED) |
| Invariant Generator | `/blocksecops-api-service/src/services/invariant_generator.py` | Invariant generation service (TO BE CREATED) |

### Database Values

In `user_quotas` table, use these values for the `create_user_quota()` trigger:

```sql
-- Developer tier (Free)
monthly_contract_limit = 3,
max_loc_per_scan = -1,
max_files_per_scan = -1,
scan_priority = 50,
max_projects = 3,
max_team_members = 2,
monthly_api_calls_limit = 0,
api_access_enabled = false,
private_repos_limit = 0,
multi_chain_enabled = false,
continuous_monitoring_enabled = false,
fp_reduction_enabled = false,
webhooks_enabled = false,
export_enabled = true,
result_retention_days = 7,
monthly_ai_explanations_limit = 0,
monthly_invariant_generations_limit = 0,
monthly_nl_conversions_limit = 0

-- Team tier
monthly_contract_limit = 15,
max_loc_per_scan = -1,
max_files_per_scan = -1,
scan_priority = 40,
max_projects = 10,
max_team_members = 5,
monthly_api_calls_limit = 0,
api_access_enabled = false,
private_repos_limit = 3,
multi_chain_enabled = false,
continuous_monitoring_enabled = false,
fp_reduction_enabled = true,
webhooks_enabled = true,
export_enabled = true,
result_retention_days = 90,
monthly_ai_explanations_limit = 50,
monthly_invariant_generations_limit = 10,
monthly_nl_conversions_limit = 25

-- Growth tier
monthly_contract_limit = 50,
max_loc_per_scan = -1,
max_files_per_scan = -1,
scan_priority = 25,
max_projects = -1,
max_team_members = 15,
monthly_api_calls_limit = -1,
api_access_enabled = true,
private_repos_limit = -1,
multi_chain_enabled = true,
continuous_monitoring_enabled = true,
fp_reduction_enabled = true,
webhooks_enabled = true,
export_enabled = true,
result_retention_days = 180,
monthly_ai_explanations_limit = 200,
monthly_invariant_generations_limit = 50,
monthly_nl_conversions_limit = 100

-- Enterprise tier
monthly_contract_limit = -1,
max_loc_per_scan = -1,
max_files_per_scan = -1,
scan_priority = 5,
max_projects = -1,
max_team_members = -1,
monthly_api_calls_limit = -1,
api_access_enabled = true,
private_repos_limit = -1,
multi_chain_enabled = true,
continuous_monitoring_enabled = true,
fp_reduction_enabled = true,
webhooks_enabled = true,
export_enabled = true,
result_retention_days = 365,
monthly_ai_explanations_limit = -1,
monthly_invariant_generations_limit = -1,
monthly_nl_conversions_limit = -1
```

---

## Related Documentation

- [Database Migrations](../database/MIGRATIONS.md) - Migration 024 tier restructure
- [Database Schema](../database/SCHEMA.md) - user_quotas table
- [API Billing Endpoints](../../blocksecops-docs/API/endpoints.md) - Billing API
- [Competitive Analysis](/Users/pwner/.claude/plans/humble-bubbling-rabin.md) - Full pricing research
- [Pricing Tiers Specification](../../TaskDocs-Apogee/phases/FREEMIUM-MODEL/PRICING-TIERS-SPECIFICATION.md) - Detailed tier specification
- [AI Invariant Generation Plan](../../TaskDocs-Apogee/phases/05-phase-5-ai-ml/TASK-6-AI-INVARIANT-GENERATION.md) - AI invariant feature details
- [Economic Security Enhancement](../../TaskDocs-Apogee/phases/05-phase-5.5-security-graph-Economic-security-analysis/FEATURE-1-ECONOMIC-SECURITY-TASKS.md) - Economic AI explainer details
