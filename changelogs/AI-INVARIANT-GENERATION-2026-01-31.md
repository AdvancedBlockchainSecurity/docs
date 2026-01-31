# AI Invariant Generation - v0.20.0

**Date**: January 31, 2026
**Type**: New Feature
**Components**: API Service, Database

## Summary

Implemented AI-powered invariant generation for smart contract formal verification using Claude AI. This feature automatically generates formal verification invariants from Solidity source code, helping developers create robust specifications without deep expertise in formal methods.

## Changes

### New Features

#### API Endpoints
- `POST /api/v1/invariants/generate` - Generate invariants from contract source
- `GET /api/v1/invariants/templates` - List available invariant templates
- `GET /api/v1/invariants/quota` - Check remaining quota
- `GET /api/v1/invariants/{id}` - Get specific generated invariant
- `GET /api/v1/invariants/contract/{contract_id}` - List invariants for contract

#### Invariant Types
- **Reentrancy Guards** - Prevent reentrancy attacks
- **Arithmetic Bounds** - Overflow/underflow protection
- **Access Control** - Role-based permission checks
- **State Consistency** - State machine invariants
- **Balance Invariants** - ERC20/ERC721 balance checks

#### Security Features
- Prompt injection detection with 15+ pattern checks
- Input validation (max 500KB contract size)
- Rate limiting (10 requests/minute)
- Tier-based access control

### Database Changes

#### New Tables
```sql
-- Migration 059: add_invariant_tables
CREATE TABLE invariant_templates (
    id UUID PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    category VARCHAR(50) NOT NULL,
    template_code TEXT NOT NULL,
    description TEXT,
    variables JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE generated_invariants (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    contract_id UUID REFERENCES contracts(id),
    template_id UUID REFERENCES invariant_templates(id),
    invariant_name VARCHAR(100) NOT NULL,
    invariant_type VARCHAR(50) NOT NULL,
    solidity_code TEXT NOT NULL,
    natural_language TEXT,
    confidence DECIMAL(3,2),
    focus_areas TEXT[],
    model_used VARCHAR(100),
    tokens_input INTEGER,
    tokens_output INTEGER,
    generation_time_ms INTEGER,
    is_cached BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE invariant_generation_history (
    id UUID PRIMARY KEY,
    user_id UUID REFERENCES users(id),
    contract_id UUID REFERENCES contracts(id),
    request_hash VARCHAR(64),
    focus_areas TEXT[],
    success BOOLEAN,
    error_message TEXT,
    generation_time_ms INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### Pre-seeded Templates
- 5 standard invariant templates included
- ERC20 balance consistency
- ERC721 ownership uniqueness
- Access control modifiers
- Reentrancy lock patterns
- Arithmetic safety checks

### Tier Quotas

| Tier | Monthly Limit | Rate Limit |
|------|--------------|------------|
| Developer | Blocked | N/A |
| Team | 10/month | 10/min |
| Growth | 50/month | 10/min |
| Enterprise | Unlimited | 10/min |

### Files Changed

#### New Files
- `src/ml/invariant_generator.py` - Core AI generation logic
- `src/application/services/invariant_service.py` - Business logic
- `src/api/routers/invariants.py` - API endpoints
- `src/domain/models/invariant.py` - Domain models
- `alembic/versions/20260131_0600-059_add_invariant_tables.py` - Migration

#### Modified Files
- `src/api/main.py` - Added invariants router
- `pyproject.toml` - Version bump to 0.20.0
- `blocksecops-shared/tier-config/` - Added invariant quotas

### Bug Fixes

- Fixed `staticcall` regex pattern typo in prompt injection detection
- Fixed prompt injection pattern to handle flexible word order ("Ignore all previous instructions")
- Fixed Pydantic tier config attribute access (`.quotas.monthly_ai_invariants_limit`)
- Fixed asyncpg multi-statement error in migration 058

## Testing

### Unit Tests
- 46 tests passing
- Coverage: invariant_generator.py, invariant_service.py

### Security Tests
- 32 prompt injection tests passing
- Pattern detection verified for all OWASP injection types

### Integration Tests
- End-to-end generation flow verified
- Quota tracking verified
- Caching behavior verified

## Deployment

### Prerequisites
- Anthropic API key in Vault at `secret/api-service/anthropic`
- Database migrations 058 and 059 applied

### Deployment Steps
1. Apply database migrations
2. Deploy API service v0.20.0
3. Verify Vault secrets accessible
4. Test endpoint health

## Rollback

If issues occur:
1. Revert API service to v0.19.x
2. Migrations are backward compatible (no data loss)

## Related

- Feature Test: [#50 AI Invariant Generation](/docs/feature-tests/50-ai-invariant-generation.md)
- Phase Documentation: [Phase E - AI Invariants](/TaskDocs-BlockSecOps/phases/04-phase-5-ai-ml/phase-e-ai-invariants.md)
- User Guide: [Invariants](/blocksecops-docs/platform/invariants/README.md)
