# Dashboard v0.46.2 - CTA Upgrades, Security Hardening, Upload Button Fix

**Component:** blocksecops-dashboard
**Scope:** Replace system errors with upgrade CTAs, security-first error handling, upload button visibility
**Date:** February 23, 2026
**Status:** Deployed

---

## Summary

Three categories of improvements:

1. **CTA Upgrade Links**: Replaced generic error messages with styled upgrade call-to-action links across 8 components where tier-gated features return 403/429 errors
2. **Security Hardening**: Replaced fragile string-matching error detection (`err.message.includes('403')`) with proper HTTP status code inspection via new `getErrorStatus()` helper
3. **Upload Button Fix**: Changed invisible upload button from `bg-blue-600` to visible `bg-[#00D4FF]` with dark text

---

## CTA Upgrade Changes

### Components Updated

| Component | Error Type | CTA Destination |
|-----------|-----------|-----------------|
| `VulnerabilityDetail.tsx` | AI Review (403) | `/pricing` — "Requires Team tier" |
| `VulnerabilityDetail.tsx` | Code Repair (403) | `/pricing` — "Requires Team tier" |
| `VulnerabilityDetail.tsx` | PoC Exploit (403) | `/pricing` — "Requires Growth tier" |
| `VulnerabilityDetail.tsx` | Invariant Gen (403) | `/pricing` — "Requires Team tier" |
| `CopilotPage.tsx` | Chat (403) | `/pricing` — "Upgrade to Team" banner |
| `EconomicSecurityPanel.tsx` | Panel (403) | `/pricing` — Upgrade prompt |
| `GenerateExploitModal.tsx` | Quota exceeded | `/pricing` — "Upgrade Plan" button |
| `GenerateInvariantsModal.tsx` | Quota exceeded | `/pricing` — "Upgrade Plan" button |
| `QuotaWidget.tsx` | Non-enterprise tiers | `/pricing` — Context-aware labels |

### CTA Design Pattern

Error states use sentinel values that are caught by conditional rendering:

```typescript
// Set sentinel (never displayed as raw text)
setReviewError('upgrade_team');

// Render upgrade CTA or error message
{reviewError && (reviewError.startsWith('upgrade_') ? (
  <p className="text-xs text-purple-400">
    Requires Team tier. <a href="/pricing" className="underline">Upgrade</a>
  </p>
) : (
  <p className="text-xs text-red-600">{reviewError}</p>
))}
```

---

## Security Hardening

### Problem

Error detection used fragile string matching that could false-positive:

```typescript
// INSECURE: Could match any error containing "403"
if (err.message.includes('403')) { ... }
```

### Solution

Created `getErrorStatus()` helper in `client.ts` that inspects `AxiosError.response.status` directly:

```typescript
export function getErrorStatus(error: unknown): number | undefined {
  if (error instanceof AxiosError) {
    return error.response?.status;
  }
  return undefined;
}
```

### Files Updated

Replaced all `err.message.includes()` patterns with `getErrorStatus()` in:

- `VulnerabilityDetail.tsx` — 4 error handlers (403 detection)
- `CopilotPage.tsx` — 5 error handlers (403, 429, 503 detection)
- `EconomicSecurityPanel.tsx` — 2 error handlers (403, 402 detection)

**Total:** 11 instances of string-matching replaced with proper status code checking.

---

## Upload Button Fix

### Problem

The contract upload button in `ContractUploadModal.tsx` used `bg-blue-600` which was invisible against the dark cyberpunk theme background.

### Fix

Changed to the platform's primary accent color with proper contrast:

```tsx
// Before (invisible)
className="bg-blue-600 text-white ..."

// After (visible)
className="bg-[#00D4FF] text-gray-900 hover:shadow-[0_0_15px_rgba(0,212,255,0.3)] ..."
```

---

## Files Modified

### blocksecops-dashboard

- `src/lib/api/client.ts` — Added `getErrorStatus()` helper
- `src/pages/VulnerabilityDetail.tsx` — CTA upgrades + security hardening
- `src/pages/copilot/CopilotPage.tsx` — CTA upgrades + security hardening
- `src/components/economic-analysis/EconomicSecurityPanel.tsx` — CTA + security hardening
- `src/components/exploits/GenerateExploitModal.tsx` — CTA upgrade link
- `src/components/invariants/GenerateInvariantsModal.tsx` — CTA upgrade link
- `src/components/QuotaWidget.tsx` — Upgrade button for all non-enterprise tiers
- `src/components/contracts/ContractUploadModal.tsx` — Upload button color fix
- `package.json` — Version 0.46.1 → 0.46.2
- `k8s/overlays/local/kustomization.yaml` — newTag and version label updated

---

## Verification

1. Upload button visible on contract upload modal (electric cyan on dark background)
2. Tier-gated features show purple "Upgrade" links instead of red error text
3. QuotaWidget shows upgrade button for free/team/growth tier users
4. Copilot chat shows "Upgrade to Team" banner for developer-tier users
5. Economic Security panel shows upgrade prompt for developer-tier users
6. No raw sentinel values (`upgrade_team`, `upgrade_required`) visible in UI

---

## Use When

- Adding new tier-gated features that need upgrade CTAs
- Implementing error handling for API calls (always use `getErrorStatus()`)
- Understanding the CTA sentinel pattern for error states
- Debugging upload button visibility on dark theme
