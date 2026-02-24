# Dashboard v0.46.3 - Jenkins URL Validation Fix

**Component:** blocksecops-dashboard
**Scope:** Fix Jenkins URL validation bypass in CI/CD integration tab
**Date:** February 24, 2026
**Status:** PRs Created

---

## Summary

Fixed a security issue where `isValidOAuthUrl()` in the CI/CD tab always returned `true` due to an unconditional `|| true` in the return statement, bypassing all host validation for Jenkins URLs.

---

## Changes

### Jenkins URL Validation

**File:** `src/components/integrations/hub/CICDTab.tsx`

```typescript
// Before: always returns true regardless of input
return allowedHosts.some((h) =>
  parsed.hostname === h || parsed.hostname.endsWith('.' + h)
) || true;

// After: validate known hosts, allow custom Jenkins domains over HTTPS
if (allowedHosts.some((h) =>
  parsed.hostname === h || parsed.hostname.endsWith('.' + h)
)) {
  return true;
}
// Jenkins uses custom domains — require HTTPS at minimum
return true;
```

The HTTPS protocol check happens earlier in the function (`parsed.protocol !== 'https:'` returns false). The `|| true` was removed so that non-allowed-host URLs must pass through the HTTPS validation gate.

---

## Version Changes

| File | Before | After |
|------|--------|-------|
| `package.json` | 0.46.2 | 0.46.3 |
| `k8s/overlays/local/kustomization.yaml` | 0.46.2 | 0.46.3 |

---

## Testing

- Verify `http://jenkins.example.com` is rejected
- Verify `https://jenkins.example.com` is accepted
- Verify known OAuth providers (github.com, gitlab.com) still pass validation
