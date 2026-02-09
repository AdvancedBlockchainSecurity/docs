# Dashboard v0.41.4 - Collapsible Sidebar & Quick Access

**Date:** February 9, 2026
**Component:** blocksecops-dashboard
**Type:** Feature
**Priority:** Medium
**Status:** Complete

---

## Summary

Added collapsible sidebar with smooth CSS transition and quick access page pinning. Also resolved 118 pre-existing TypeScript strict mode errors across 30+ files.

## Added

- Collapsible sidebar toggle (ChevronDoubleLeftIcon / ChevronDoubleRightIcon) at bottom of sidebar
- Sidebar transitions between expanded (`w-64`, 256px) and collapsed (`w-16`, 64px) states
- Smooth CSS transition (`transition-all duration-300`)
- Quick Access section between logo and HOME for pinned pages (max 5)
- Pin/unpin icons on nav items (StarIcon outline/solid on hover)
- `src/lib/storage/quickAccess.ts` localStorage helper module
- localStorage persistence for collapse state (`blocksecops-sidebar-collapsed`)
- localStorage persistence for pinned pages (`blocksecops-quick-access`)
- Collapsed state shows section icons only with `title` tooltips
- Mobile behavior unchanged (collapse toggle hidden, full overlay sidebar)

## Fixed

- 118 pre-existing TypeScript strict mode errors across 30+ files
- Missing type properties on `CodeRepair` interface (`vulnerability_title`, `contract_name`, `repaired_code`, `feedback`)
- Missing type properties on `ReviewSuggestion` interface (`type`, `severity`, `confidence`, `status`, etc.)
- Missing exports from `codeRepair.ts` and `codeReview.ts` modules
- Unused imports removed from 8+ component files
- `exactOptionalPropertyTypes` violations in monitoring, support tickets, pricing
- `noUncheckedIndexedAccess` violations in CICDTab, OrgSelector
- Dead code removed from FormattedDescription.tsx
- Type mismatches in TierGate.tsx, useQuota.ts, RepairDetailPage.tsx, RepairHistoryPage.tsx, ReviewDetailPage.tsx, CodeReviewPage.tsx

## Changed

- Dockerfile build command: `npm run build:no-check` to `npm run build:force` (TypeScript errors now resolved)

## New Files

| File | Purpose |
|------|---------|
| `src/lib/storage/quickAccess.ts` | localStorage helper for pinned quick access pages |
| `src/types/blocksecops-tier-config.d.ts` | Type declaration stub for `@blocksecops/tier-config` |
| `src/types/stripe.d.ts` | Type declaration stubs for `@stripe/react-stripe-js` and `@stripe/stripe-js` |

## Key Files Modified

| File | Changes |
|------|---------|
| `src/App.tsx` | Added `sidebarCollapsed` state with localStorage persistence |
| `src/components/navigation/Sidebar.tsx` | Full rewrite: collapse/expand + quick access section |
| `src/lib/api/codeRepair.ts` | Added missing types and interfaces |
| `src/lib/api/codeReview.ts` | Added missing types and interfaces |
| `src/lib/api/index.ts` | Fixed re-exports |
| `package.json` | Version bump 0.41.3 → 0.41.4 |
| `k8s/overlays/local/kustomization.yaml` | Updated newTag to 0.41.4 |
| `Dockerfile` | Changed to `npm run build:force` |

## Testing

- Build passes with `npm run build:force` (tsc + vite build)
- Docker image built and pushed to Harbor
- Deployed to Kubernetes via `kubectl apply -k`
- Sidebar collapse/expand transition verified
- Quick access pin/unpin verified
- localStorage persistence verified across page refresh
- Mobile overlay sidebar behavior unchanged

## Impact

- **User-facing:** New sidebar collapse feature gives users more screen space; quick access provides fast navigation to frequently used pages
- **Performance:** No performance impact; CSS transition only
- **Breaking changes:** None — backwards compatible

## Related Documentation

- [Feature Test 60](../feature-tests/60-collapsible-sidebar-quick-access.md)
- [Navigation Guide](../../blocksecops-docs/platform/dashboard/navigation.md)
- [Docker Image Versioning](../standards/docker-image-versioning.md)
