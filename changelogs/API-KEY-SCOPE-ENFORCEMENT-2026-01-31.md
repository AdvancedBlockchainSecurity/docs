# API Key Scope Enforcement Implementation

**Date:** January 31, 2026
**Version:** API Service 0.20.2
**Type:** Security Enhancement

## Summary

Implemented comprehensive API key scope enforcement for all write endpoints. Previously, API keys with read-only scopes could access write endpoints, creating a security gap.

## Changes

### New Authentication Dependency

Added `require_auth_with_scope()` to `src/infrastructure/auth/api_key_auth.py`:

```python
def require_auth_with_scope(required_scopes: List[str]) -> Callable:
    """
    Creates a dependency that:
    1. Accepts either Bearer token OR API key authentication
    2. For API key users: enforces scope requirements
    3. For Bearer token users: allows full access (authenticated via dashboard)
    """
```

### Updated Endpoints (17 total)

| File | Endpoint | Scope |
|------|----------|-------|
| contracts.py | POST /contracts | `contracts:write` |
| contracts.py | PUT /contracts/{id} | `contracts:write` |
| contracts.py | DELETE /contracts/{id} | `contracts:write` |
| contracts.py | DELETE /contracts (batch) | `contracts:write` |
| scans.py | POST /scans | `scans:create` |
| scans.py | POST /scans/batch | `scans:create` |
| scans.py | DELETE /scans/{id} | `scans:create` |
| scans.py | DELETE /scans (batch) | `scans:create` |
| upload.py | POST /upload | `contracts:write` |
| vulnerabilities.py | PATCH /vulnerabilities/{id}/status | `vulnerabilities:write` |
| webhooks.py | POST /webhooks | `webhooks:write` |
| webhooks.py | PATCH /webhooks/{id} | `webhooks:write` |
| webhooks.py | DELETE /webhooks/{id} | `webhooks:write` |
| webhooks.py | POST /webhooks/{id}/rotate-secret | `webhooks:write` |
| quality_gates.py | PUT /quality-gates/projects/{id} | `quality-gates:write` |
| quality_gates.py | PATCH /quality-gates/projects/{id} | `quality-gates:write` |
| quality_gates.py | POST /quality-gates/projects/{id}/evaluate | `quality-gates:read` |

### New Scopes Added

- `quality-gates:read`
- `quality-gates:write`

## Security Impact

**Before:** An API key with `scans:read` scope could:
- Create/delete contracts (data loss risk)
- Trigger scans (quota/billing impact)
- Delete scans (audit trail loss)

**After:** API keys are strictly limited to their assigned scopes. Write operations require explicit write scopes.

## Testing

```bash
# Test scope enforcement (should fail with 403)
curl -sk -H 'X-API-Key: <read-only-key>' \
  -X POST -d '{"name": "Test"}' \
  'https://app.0xapogee.local/api/v1/contracts'

# Expected: 403 Forbidden with message about missing scope
```

## Documentation

- Created: `docs/standards/api-endpoint-auth.md`
- Updated: `docs/standards/INDEX.md` (added Security section)
- Created: `docs/feature-tests/api-key-scope-enforcement.md`

## Related Issues

- Fixes security gap in API key authentication
- Enables safe CLI/SDK access for programmatic workflows
- Maintains tier restrictions (growth+ only for API keys)

---

**Maintained By:** BlockSecOps Team
