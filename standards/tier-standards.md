# Tier Standards - Source of Truth

**Last Updated**: January 11, 2026
**Version**: 2.1 (AI Features Added)
**Status**: Official
**Owner**: Product Team

This document is the **single source of truth** for all tier and pricing information across the BlockSecOps platform. All other implementations must match these values.

---

## Tier Hierarchy

```
free (0) < developer (1) < startup (2) < professional (3) < enterprise (4)
```

**Tier Names** (official, use these exact strings):
- `free`
- `developer`
- `startup`
- `professional`
- `enterprise`

---

## Subscription Tiers

### Tier 1: Free

| Attribute | Value |
|-----------|-------|
| **Price** | $0 (forever) |
| **Monthly Scans** | 3 |
| **Max LoC per Scan** | 5,000 |
| **Max Files per Scan** | 5 |
| **Projects** | 3 |
| **Team Members** | 1 |
| **API Calls/Month** | 0 (no API access) |
| **Result Retention** | 7 days |
| **Scan Priority** | 50 (lowest) |
| **API Access** | No |
| **Webhooks** | No |
| **Export Reports** | No (dashboard view only) |
| **AI Explanations/Month** | 0 |
| **AI Invariant Generations/Month** | 0 |
| **Scanners** | All 17+ |
| **Support** | Community |

**Best For**: Platform trials, evaluating the product

**Restrictions**:
- No PDF/JSON/SARIF export
- Dashboard view only for results
- Limited to small contracts (5K LoC)
- No AI features

---

### Tier 2: Developer

| Attribute | Value |
|-----------|-------|
| **Price** | $189/month ($1,890/year) |
| **Monthly Scans** | 100 |
| **Max LoC per Scan** | Unlimited |
| **Max Files per Scan** | Unlimited |
| **Projects** | 5 |
| **Team Members** | 1 (solo) |
| **API Calls/Month** | 1,000 |
| **Result Retention** | 90 days |
| **Scan Priority** | 40 |
| **API Access** | Yes |
| **Webhooks** | No |
| **Export Reports** | Yes (PDF, JSON, SARIF) |
| **AI Explanations/Month** | 10 |
| **AI Invariant Generations/Month** | 5 |
| **Scanners** | All 17+ |
| **Support** | Email (48h response) |

**Best For**: Solo developers, freelancers, security researchers
**Per-Scan Cost**: $1.89

---

### Tier 3: Startup

| Attribute | Value |
|-----------|-------|
| **Price** | $489/month ($4,890/year) |
| **Monthly Scans** | 500 |
| **Max LoC per Scan** | Unlimited |
| **Max Files per Scan** | Unlimited |
| **Projects** | 20 |
| **Team Members** | 10 |
| **API Calls/Month** | 10,000 |
| **Result Retention** | 180 days |
| **Scan Priority** | 25 |
| **API Access** | Yes |
| **Webhooks** | Yes |
| **CI/CD Integration** | Yes |
| **Export Reports** | Yes (PDF, JSON, SARIF) |
| **AI Explanations/Month** | 100 |
| **AI Invariant Generations/Month** | 25 |
| **Scanners** | All 17+ |
| **Support** | Email (24h response) |

**Best For**: Small teams, startup companies, growing security practices
**Per-Scan Cost**: $0.98
**Note**: Most popular tier

---

### Tier 4: Professional

| Attribute | Value |
|-----------|-------|
| **Price** | $1,956/month ($19,560/year) |
| **Monthly Scans** | Unlimited (-1) |
| **Max LoC per Scan** | Unlimited (-1) |
| **Max Files per Scan** | Unlimited (-1) |
| **Projects** | Unlimited (-1) |
| **Team Members** | 25 |
| **API Calls/Month** | Unlimited (-1) |
| **Result Retention** | 365 days |
| **Scan Priority** | 10 |
| **API Access** | Yes |
| **Webhooks** | Yes |
| **CI/CD Integration** | Yes |
| **Organizations** | Yes |
| **Audit Logs** | Yes |
| **Export Reports** | Yes (PDF, JSON, SARIF) |
| **AI Explanations/Month** | 500 |
| **AI Invariant Generations/Month** | 100 |
| **AI Priority Queue** | Yes |
| **Scanners** | All 17+ |
| **Support** | Priority (4h SLA) |

**Best For**: Security firms, protocol teams, agencies with multiple clients
**Price Multiplier**: 4.0x from Startup

---

### Tier 5: Enterprise

| Attribute | Value |
|-----------|-------|
| **Price** | Custom (contact sales) |
| **Monthly Scans** | Unlimited (-1) |
| **Max LoC per Scan** | Unlimited (-1) |
| **Max Files per Scan** | Unlimited (-1) |
| **Projects** | Unlimited (-1) |
| **Team Members** | Unlimited (-1) |
| **API Calls/Month** | Unlimited (-1) |
| **Result Retention** | 730 days (2 years) |
| **Scan Priority** | 5 (highest) |
| **API Access** | Yes |
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
| **Scanners** | All 17+ |
| **Support** | 24/7 Dedicated Account Manager |

**Best For**: Large organizations, regulated industries, enterprise security teams

---

## Quick Reference Table

### Quota Limits

| Metric | Free | Developer | Startup | Professional | Enterprise |
|--------|------|-----------|---------|--------------|------------|
| Monthly Scans | 3 | 100 | 500 | -1 | -1 |
| Max LoC per Scan | 5,000 | -1 | -1 | -1 | -1 |
| Max Files per Scan | 5 | -1 | -1 | -1 | -1 |
| Projects | 3 | 5 | 20 | -1 | -1 |
| Team Members | 1 | 1 | 10 | 25 | -1 |
| API Calls/Month | 0 | 1,000 | 10,000 | -1 | -1 |
| AI Explanations/Month | 0 | 10 | 100 | 500 | -1 |
| AI Invariant Gens/Month | 0 | 5 | 25 | 100 | -1 |
| Result Retention (days) | 7 | 90 | 180 | 365 | 730 |
| Scan Priority | 50 | 40 | 25 | 10 | 5 |

**Note**: `-1` means unlimited

### Feature Availability

| Feature | Free | Developer | Startup | Professional | Enterprise |
|---------|------|-----------|---------|--------------|------------|
| All 17+ Scanners | Yes | Yes | Yes | Yes | Yes |
| Export Reports | No | Yes | Yes | Yes | Yes |
| API Access | No | Yes | Yes | Yes | Yes |
| Webhooks | No | No | Yes | Yes | Yes |
| CI/CD Integration | No | No | Yes | Yes | Yes |
| AI Explanations | No | Yes | Yes | Yes | Yes |
| AI Invariants | No | Yes | Yes | Yes | Yes |
| AI Priority Queue | No | No | No | Yes | Yes |
| Organizations | No | No | No | Yes | Yes |
| Audit Logs | No | No | No | Yes | Yes |
| SSO/SAML | No | No | No | No | Yes |
| SLA Guarantee | No | No | No | No | 99.9% |

### Pricing

| Tier | Monthly | Annual | Savings | Per-Scan |
|------|---------|--------|---------|----------|
| Free | $0 | $0 | - | - |
| Developer | $189 | $1,890 | 17% | $1.89 |
| Startup | $489 | $4,890 | 17% | $0.98 |
| Professional | $1,956 | $19,560 | 17% | ~$0 |
| Enterprise | Custom | Custom | - | ~$0 |

### Price Multipliers

| Tier Jump | Multiplier |
|-----------|------------|
| Developer → Startup | 2.6x |
| Startup → Professional | 4.0x |

### Support Levels

| Tier | Support Type | Response Time |
|------|--------------|---------------|
| Free | Community | Best effort |
| Developer | Email | 48 hours |
| Startup | Email | 24 hours |
| Professional | Priority | 4 hours |
| Enterprise | Dedicated | 24/7 |

---

## AI Features (Claude Integration)

**Status**: PLANNED (Phase 5.5 & Task 6)
**Added**: January 11, 2026

AI-powered features use Claude API and are tier-gated with monthly quotas.

### AI Feature Overview

| Feature | Description | Model | Cost/Request |
|---------|-------------|-------|--------------|
| **Economic AI Explainer** | AI explanations of economic vulnerabilities | Claude Haiku 3.5 | ~$0.012 |
| **AI Invariant Generator** | Generate formal verification properties | Claude Sonnet 4 | ~$0.09 |
| **Natural Language Converter** | Convert text to invariant specs | Claude Sonnet 4 | ~$0.03 |

### AI Quota Summary

| Tier | AI Explanations | Invariant Gens | NL Conversions | Priority Queue |
|------|-----------------|----------------|----------------|----------------|
| Free | 0 | 0 | 0 | No |
| Developer | 10 | 5 | 10 | No |
| Startup | 100 | 25 | 50 | No |
| Professional | 500 | 100 | 200 | Yes |
| Enterprise | -1 | -1 | -1 | Yes |

### Claude API Pricing (January 2026)

| Model | Input (per MTok) | Output (per MTok) | Use Case |
|-------|------------------|-------------------|----------|
| Claude Haiku 3.5 | $0.80 | $4.00 | Economic explanations |
| Claude Sonnet 4 | $3.00 | $15.00 | Invariant generation |

### Monthly Cost to BlockSecOps (Absorbed in Tier)

| Tier | Typical AI Usage | Est. Monthly Cost |
|------|------------------|-------------------|
| Free | 0 | $0 |
| Developer | 10 explanations + 5 invariants | ~$0.57 |
| Startup | 100 explanations + 25 invariants | ~$3.45 |
| Professional | 500 explanations + 100 invariants | ~$15.00 |
| Enterprise | Variable | Usage-based billing |

### Implementation

**Database Columns** (add to `user_quotas`):
```sql
monthly_ai_explanations_limit INTEGER DEFAULT 0
monthly_ai_explanations_used INTEGER DEFAULT 0
monthly_invariant_generations_limit INTEGER DEFAULT 0
monthly_invariant_generations_used INTEGER DEFAULT 0
monthly_nl_conversions_limit INTEGER DEFAULT 0
monthly_nl_conversions_used INTEGER DEFAULT 0
```

**Environment Variables**:
```bash
ANTHROPIC_API_KEY=sk-ant-...
ECONOMIC_AI_MODEL=claude-3-haiku-20240307
INVARIANT_AI_MODEL=claude-sonnet-4-20250514
```

**Tier Gating**:
```python
@require_tier(TierName.DEVELOPER)
@require_ai_quota("economic_explanation")
async def explain_economic_risks(...):
    ...
```

---

## Pay-Per-Scan (x402)

**Status**: FINALIZED (January 2026)

Pay-per-scan pricing via x402 (USDC on Base) for users who prefer per-scan billing over subscriptions.

### Hybrid Model: File-Based Tiers with LoC Limits

**Primary**: File count determines tier (user-friendly)
**Secondary**: Max LoC limit prevents abuse

| Tier | File Count | Max LoC | Price (USDC) | Export |
|------|------------|---------|--------------|--------|
| Micro | 1-5 files | 4,000 | **$3.00** | Yes |
| Small | 6-25 files | 20,000 | **$7.00** | Yes |
| Medium | 26-100 files | 75,000 | **$15.00** | Yes |
| Large | 100+ files | Unlimited | **$25.00** | Yes |

### Competitive Analysis

| Platform | Model | Per-Scan Cost | Scanners |
|----------|-------|---------------|----------|
| BlockSecOps x402 | Hybrid | $3-25 | 17+ |
| MythX On-Demand | Per-scan | $3.33 | 1 |
| SolidityScan On-Demand | LoC-based | $15-30 | 1 |

**Value Proposition**: "Pay similar to MythX, get 17x the scanners"

### Subscription Break-Even

| x402 Usage (Small tier) | x402 Cost | Better Option |
|-------------------------|-----------|---------------|
| 10 scans/month | $70 | x402 |
| 20 scans/month | $140 | x402 |
| 27+ scans/month | $189+ | Developer ($189) |
| 70+ scans/month | $490+ | Startup ($489) |

### Environment Variables

```bash
# x402 pricing (USDC)
SCAN_PRICE_MICRO=3.00
SCAN_PRICE_SMALL=7.00
SCAN_PRICE_MEDIUM=15.00
SCAN_PRICE_LARGE=25.00

# LoC limits per tier
SCAN_LOC_LIMIT_MICRO=4000
SCAN_LOC_LIMIT_SMALL=20000
SCAN_LOC_LIMIT_MEDIUM=75000
SCAN_LOC_LIMIT_LARGE=-1  # Unlimited
```

---

## Implementation Reference

### Source Files That Must Match These Standards

| Component | File Path | What to Update |
|-----------|-----------|----------------|
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
-- Free tier
monthly_scan_limit = 3,
max_loc_per_scan = 5000,
max_files_per_scan = 5,
scan_priority = 50,
max_projects = 3,
max_team_members = 1,
monthly_api_calls_limit = 0,
api_access_enabled = false,
webhooks_enabled = false,
export_enabled = false,
result_retention_days = 7,
monthly_ai_explanations_limit = 0,
monthly_invariant_generations_limit = 0,
monthly_nl_conversions_limit = 0

-- Developer tier
monthly_scan_limit = 100,
max_loc_per_scan = -1,
max_files_per_scan = -1,
scan_priority = 40,
max_projects = 5,
max_team_members = 1,
monthly_api_calls_limit = 1000,
api_access_enabled = true,
webhooks_enabled = false,
export_enabled = true,
result_retention_days = 90,
monthly_ai_explanations_limit = 10,
monthly_invariant_generations_limit = 5,
monthly_nl_conversions_limit = 10

-- Startup tier
monthly_scan_limit = 500,
max_loc_per_scan = -1,
max_files_per_scan = -1,
scan_priority = 25,
max_projects = 20,
max_team_members = 10,
monthly_api_calls_limit = 10000,
api_access_enabled = true,
webhooks_enabled = true,
export_enabled = true,
result_retention_days = 180,
monthly_ai_explanations_limit = 100,
monthly_invariant_generations_limit = 25,
monthly_nl_conversions_limit = 50

-- Professional tier
monthly_scan_limit = -1,
max_loc_per_scan = -1,
max_files_per_scan = -1,
scan_priority = 10,
max_projects = -1,
max_team_members = 25,
monthly_api_calls_limit = -1,
api_access_enabled = true,
webhooks_enabled = true,
export_enabled = true,
result_retention_days = 365,
monthly_ai_explanations_limit = 500,
monthly_invariant_generations_limit = 100,
monthly_nl_conversions_limit = 200

-- Enterprise tier
monthly_scan_limit = -1,
max_loc_per_scan = -1,
max_files_per_scan = -1,
scan_priority = 5,
max_projects = -1,
max_team_members = -1,
monthly_api_calls_limit = -1,
api_access_enabled = true,
webhooks_enabled = true,
export_enabled = true,
result_retention_days = 730,
monthly_ai_explanations_limit = -1,
monthly_invariant_generations_limit = -1,
monthly_nl_conversions_limit = -1
```

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| 2026-01-11 | **v2.1**: Added AI Features section with tier quotas (AI Explanations, Invariant Generations, NL Conversions). Claude API costs documented. Database schema updated. | Claude Code |
| 2026-01-11 | Competitive pricing update: Free (3 scans, 5K LoC, no export), Developer ($189), Startup ($489), Professional ($1,956). x402 hybrid model finalized ($3/$7/$15/$25). | Claude Code |
| 2026-01-11 | Initial creation, consolidated from all sources | Claude Code |

---

## Related Documentation

- [Database Migrations](../database/MIGRATIONS.md) - Migration 024 tier restructure
- [Database Schema](../database/SCHEMA.md) - user_quotas table
- [API Billing Endpoints](../../blocksecops-docs/API/endpoints.md) - Billing API
- [Competitive Analysis](/Users/pwner/.claude/plans/humble-bubbling-rabin.md) - Full pricing research
- [Pricing Tiers Specification](../../TaskDocs-BlockSecOps/phases/FREEMIUM-MODEL/PRICING-TIERS-SPECIFICATION.md) - Detailed tier specification
- [AI Invariant Generation Plan](../../TaskDocs-BlockSecOps/phases/05-phase-5-ai-ml/TASK-6-AI-INVARIANT-GENERATION.md) - AI invariant feature details
- [Economic Security Enhancement](../../TaskDocs-BlockSecOps/phases/05-phase-5.5-security-graph-Economic-security-analysis/FEATURE-1-ECONOMIC-SECURITY-TASKS.md) - Economic AI explainer details
