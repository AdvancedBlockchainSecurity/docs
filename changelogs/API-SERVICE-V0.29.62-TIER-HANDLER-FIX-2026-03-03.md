# API Service v0.29.62 — Tier Change Handler Fix

**Component:** blocksecops-api-service
**Scope:** Admin tier change endpoint, CLI tier management, tier/quota consistency
**Date:** March 3, 2026
**Status:** Deployed
**RCA:** TaskDocs-BlockSecOps/audits/RCA-TIER-QUOTA-MISMATCH-2026-03-03.md

---

## Summary

Fixed critical issue where admin tier changes bypassed the tier change handler, causing tier and quota data mismatches. Both the admin user update endpoint (PATCH /admin/users/{id}) and CLI set-user-tier command now properly route through `handle_tier_change()`, ensuring all related data (users.tier, user_quotas, sessions, API keys, audit logs) stays synchronized.

---

## Changes

### 1. Admin User Update Endpoint

**File:** `src/presentation/api/v1/endpoints/admin/users.py`

Previously, the endpoint directly updated ORM fields, bypassing tier change logic:

```python
# Before: Direct ORM assignment bypasses tier change handler
if tier is not None and tier != user.tier:
    user.tier = tier  # ❌ Skips handle_tier_change()

# After: Routes through tier change handler
if tier is not None and tier != user.tier:
    await handle_tier_change(user_id=user.id, new_tier=tier)  # ✅ Proper flow
```

**Impact:** Admin updates to user tiers now properly invalidate sessions, flag API keys, update quotas, and create audit logs.

### 2. CLI Set-User-Tier Command

**File:** `src/cli/admin.py`

Previously, the CLI command bypassed the tier change handler:

```python
# Before: Direct database update skips handler logic
session.query(UserModel).filter_by(id=user_id).update({"tier": new_tier})
session.commit()

# After: Routes through tier change handler
await handle_tier_change(user_id=user_id, new_tier=new_tier)
```

**Impact:** CLI tier changes now have full consistency guarantees matching the API endpoint behavior.

### 3. Tier Change Handler Behavior

The `handle_tier_change()` function in `src/application/services/user_service.py` ensures:

- Updates `users.tier`
- Updates `user_quotas.tier` and resets monthly scan counters
- Invalidates all user sessions (forces re-authentication)
- Flags all user API keys as requiring re-authorization
- Creates audit log entry with old/new tier values
- Maintains single transaction (all-or-nothing consistency)

### 4. Version Bumps

- `pyproject.toml`: 0.29.61 → 0.29.62
- `k8s/overlays/local/api-service/kustomization.yaml`: 0.29.61 → 0.29.62

---

## Files Modified

| File | Change |
|------|--------|
| `src/presentation/api/v1/endpoints/admin/users.py` | Route tier changes through handle_tier_change() |
| `src/cli/admin.py` | Route CLI tier changes through handle_tier_change() |
| `src/application/services/user_service.py` | Ensure handle_tier_change() maintains all invariants |
| `pyproject.toml` | Version 0.29.61 → 0.29.62 |
| `k8s/overlays/local/api-service/kustomization.yaml` | Version 0.29.61 → 0.29.62 |

---

## Root Cause Analysis

Two code paths for changing user tiers existed:

1. **Proper path:** API endpoint calls `tier_change_handler()` → Updates tier + quotas + sessions + keys + audit
2. **Broken paths:**
   - Admin PATCH endpoint did direct ORM assignment
   - CLI command did direct database UPDATE

**Why this matters:** Tier changes must be atomic — all related data must update together. The handler ensures:
- Session invalidation prevents stale cached tier values
- API key reflagging prevents unauthorized quota use
- Quota reset prevents carry-over from previous tier
- Audit trail documents tier changes

When these steps were skipped, users could:
- Keep old cached tier in active sessions
- Continue using old API keys with wrong tier scopes
- Maintain quotas from previous tier instead of new tier limits

**Detection:** RCA-TIER-QUOTA-MISMATCH-2026-03-03 audit identified instances where admin changed user tier but user_quotas and sessions retained old values.

---

## Testing

- Unit tests for `handle_tier_change()` verify:
  - users.tier updated correctly
  - user_quotas.tier and monthly_scans_used reset
  - Sessions marked for invalidation
  - API keys flagged for re-auth
  - Audit log entry created

- Integration tests for admin endpoint verify:
  - PATCH /admin/users/{id} with tier change triggers full handler
  - Response includes updated tier and quota information

- CLI command tested with multiple tier transitions:
  - developer → starter → growth → enterprise
  - enterprise → developer (downgrade)
  - Same tier (no-op, no changes)

---

## Verification

After deployment, verify tier changes work correctly:

```bash
# Test admin endpoint
curl -X PATCH http://127.0.0.1:8000/api/v1/admin/users/{user-id} \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tier": "growth"}'

# Verify user's quota was updated
curl http://127.0.0.1:8000/api/v1/users/me/quota \
  -H "Authorization: Bearer $USER_TOKEN"

# Verify old sessions invalidated (user must re-login)
# Old session tokens should return 401 Unauthorized
curl http://127.0.0.1:8000/api/v1/health/ready \
  -H "Authorization: Bearer $OLD_SESSION_TOKEN"
```

---

## Related Documentation

- **RCA:** TaskDocs-BlockSecOps/audits/RCA-TIER-QUOTA-MISMATCH-2026-03-03.md
- **Standards:** docs/standards/tier-standards.md
- **Database Migration:** docs/database/MIGRATIONS.md → Migration 079 (team → starter rename)
- **API Endpoint Auth:** docs/standards/api-endpoint-auth.md
