# AI Code Repair Pipeline

AI-powered code fix generation for vulnerabilities. Takes original vulnerable code and generates a patched version with explanation. Uses Claude Sonnet for high-quality repair output.

## Overview

```
Dashboard (Finding Detail)   API Service (code_repair.py → CodeRepairService)   External
──────────────────────────   ────────────────────────────────────────────────   ────────
POST /code-repair/generate → 1. Authenticate (JWT)                              PostgreSQL
                             2. Validate tier (team+)
                             3. Check feature flags
                             4. Rate limit check
                             5. Build repair context (vuln + source code)
                             6. Call Anthropic Claude API
                             7. Store repair with diff
                      ←      Return RepairResponse (201)                        Anthropic API
```

## Trigger

- **Dashboard**: User clicks "AI Repair" on a vulnerability finding
- **Input**: `vulnerability_id`, `original_code`, `file_path`, `start_line`, `end_line`

## Pipeline Steps

| # | Step | Component | Description |
|---|------|-----------|-------------|
| 1 | Authentication | `get_current_user` | JWT required |
| 2 | Tier gate | `require_tier("team")` | Developer tier blocked |
| 3 | Feature flags | `ai_features_enabled` + `ai_code_repair_enabled` | Returns 503 if disabled |
| 4 | Rate limiting | `@limiter.limit(get_rate_limit_string("ai", "codeRepair"))` | Per-tier rate limits (BSO-SEC-AI-003) |
| 5 | Load context | Database query | Fetch vulnerability details, surrounding code context |
| 6 | Anthropic API call | `CodeRepairService.generate_repair()` | Model: `claude-sonnet-4-20250514`, max tokens: 4096 |
| 7 | Store result | Database INSERT | Save repair with repaired_code, explanation, diff |

## Configuration

| Setting | Default | Source |
|---------|---------|--------|
| `anthropic_model_code_repair` | `claude-sonnet-4-20250514` | `config.py` |
| `anthropic_max_tokens_code_repair` | 4096 | `config.py` |
| `ai_code_repair_enabled` | `true` | `config.py` |

## API Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/code-repair/generate` | JWT + `require_tier("team")` + rate limit | Generate AI repair |
| GET | `/code-repair/repairs/{repair_id}` | JWT | Get specific repair |
| GET | `/code-repair/vulnerabilities/{vuln_id}/repairs` | JWT | List repairs for finding |
| GET | `/code-repair/repairs` | JWT | List all user repairs |
| POST | `/code-repair/repairs/{repair_id}/apply` | JWT | Mark repair as applied |
| POST | `/code-repair/repairs/{repair_id}/feedback` | JWT | Submit feedback |
| DELETE | `/code-repair/repairs/{repair_id}` | JWT | Delete repair |
| GET | `/code-repair/statistics` | JWT | Repair statistics |

## Files

| File | Role |
|------|------|
| `src/presentation/api/v1/endpoints/code_repair.py` | Endpoint definitions, tier gating, rate limiting |
| `src/application/services/code_repair_service.py` | Anthropic API integration, diff generation |
| `src/infrastructure/config.py` | Model selection, token limits |

## Error Handling

| Error | HTTP | Response |
|-------|------|----------|
| Feature disabled | 503 | `{"detail": "AI Code Repair is currently disabled"}` |
| Tier insufficient | 403 | Tier gate rejection |
| Rate limited | 429 | Too many requests |
| Vulnerability not found | 404 | Standard not found |
| Anthropic API failure | 500 | Sanitized error via `get_safe_error_detail()` |

## Tier Quotas

| Tier | Code Repair Requests/Month |
|------|----------------------------|
| Developer | 0 (blocked) |
| Team | 10 |
| Growth | 50 |
| Enterprise | Unlimited |
