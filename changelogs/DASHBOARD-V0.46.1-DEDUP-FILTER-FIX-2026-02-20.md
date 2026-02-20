# Dashboard v0.46.1 - Deduplication Page Filter Fix

**Component:** blocksecops-dashboard
**Scope:** Fix deduplication page default min_scanner_count filter from 2 to 1
**Date:** February 20, 2026
**Status:** Deployed

---

## Summary

Fixed a bug where the `/deduplication` page showed "No deduplication groups found" when filtering by pattern codes that only had single-scanner groups. The default `min_scanner_count` filter was set to `2`, hiding all groups with only one scanner.

---

## Root Cause

The `DeduplicationList.tsx` component initialized `min_scanner_count` to `2` from URL search params:

```typescript
min_scanner_count: parseInt(searchParams.get('min_scanners') || '2', 10),
```

The `scanner_count` property on `DeduplicationGroupModel` returns the number of unique scanner keys in `scanner_distribution`. For example, `{"semgrep": 2}` has `scanner_count = 1`.

For pattern `BVD-SOLIDITY-GAS-001`, all 17 groups had `scanner_distribution = {'semgrep': 2}` (single scanner), so all were filtered out by the `min_scanner_count >= 2` post-query filter.

---

## Key Changes

- Changed default `min_scanner_count` from `2` to `1` in `DeduplicationList.tsx`
- Updated URL sync logic to only serialize `min_scanners` when it differs from the new default (`1`)
- The "1+ scanners" option was already present in the dropdown — now it's the default selection

---

## Files Modified

### blocksecops-dashboard
- `src/pages/DeduplicationList.tsx` (lines 18, 28) — Default changed from `'2'` to `'1'`
- `package.json` — Version 0.46.0 → 0.46.1
- `k8s/overlays/local/kustomization.yaml` — newTag and version label updated

---

## Verification

1. Navigate to `https://app.blocksecops.local/deduplication?pattern=BVD-SOLIDITY-GAS-001`
2. Page should show 17 deduplication groups (previously showed "No deduplication groups found")
3. Filter dropdown defaults to "1+ scanners"
4. Changing filter to "2+ scanners" correctly hides single-scanner groups

---

## Use When

- Debugging deduplication page showing no results
- Understanding the min_scanner_count filter behavior
- Modifying deduplication page filter defaults
