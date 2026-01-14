# Dashboard v0.29.0 UI Updates

**Date:** 2026-01-13
**Component:** blocksecops-dashboard
**Type:** Feature + Bug Fix
**Priority:** Medium
**Status:** Complete

---

## Summary

Dashboard v0.29.0 includes several UI updates for Phase 5.5c Quality Gates integration, search improvements, and a bug fix for filter layout overflow in the Advanced Search page.

---

## Issues Resolved

1. **Advanced Search Filter Overflow**: Filter chips in Advanced Search were overflowing outside the content area and going behind the "Saved Searches" section when window was narrow or many filters were active.

---

## Added

- **QualityGatePanel Integration**: Quality Gates panel now displays in ProjectDetail page for Developer+ tier users
- **Contracts Page Search**: Client-side search input to filter contracts by name or address
- **Contract Links in Advanced Search**: Contract results in Advanced Search are now clickable, navigating to `/contracts/{id}`

---

## Changed

- **Search Route Rename**: `/search` renamed to `/advanced-search` for clarity
- **Sidebar Navigation**: "Search" renamed to "Advanced Search" in sidebar navigation
- **SavedSearchesPanel**: Updated navigation links to use `/advanced-search`

---

## Fixed

### Advanced Search Filter Layout (v0.29.0)

**Problem**: Filter chips were overflowing outside the content container and appearing behind the "Saved Searches" sidebar section.

**Root Cause**: The filter section used nested `flex gap-2` containers without `flex-wrap`, causing chips to overflow horizontally instead of wrapping.

**Solution**: Changed the filter layout to use vertical stacking (`space-y-3`) with each filter group (Severity, Scanners, Categories) having its own `flex flex-wrap gap-2` container. Added section labels for better organization.

**Files Modified:**
- `src/pages/Search.tsx` (lines ~295-350)

**Before:**
```tsx
<div className="mt-4 flex flex-wrap gap-2">
  <div className="flex gap-2">
    {/* Severity filters - no wrap */}
  </div>
  <div className="flex gap-2">
    {/* Scanner filters - no wrap */}
  </div>
  {/* ... */}
</div>
```

**After:**
```tsx
<div className="mt-4 space-y-3">
  {/* Severity Filters */}
  <div className="flex flex-wrap gap-2">
    <span className="text-xs font-medium text-gray-500 w-full mb-1">Severity:</span>
    {/* Severity chips - now wraps */}
  </div>

  {/* Scanner Filters */}
  <div className="flex flex-wrap gap-2">
    <span className="text-xs font-medium text-gray-500 w-full mb-1">Scanners:</span>
    {/* Scanner chips - now wraps */}
  </div>

  {/* Category Filters */}
  <div className="flex flex-wrap gap-2">
    <span className="text-xs font-medium text-gray-500 w-full mb-1">Categories:</span>
    {/* Category chips - now wraps */}
  </div>

  {/* Confidence Filter and Reset */}
  <div className="flex flex-wrap items-center gap-4">
    {/* Confidence slider and reset button */}
  </div>
</div>
```

---

## Code Changes

### Files Modified

| File | Change |
|------|--------|
| `src/pages/ProjectDetail.tsx` | Added QualityGatePanel import and component |
| `src/pages/ContractsList.tsx` | Added search state, filter logic, search input UI |
| `src/App.tsx` | Changed route `/search` to `/advanced-search` |
| `src/components/navigation/Sidebar.tsx` | Changed nav item to "Advanced Search" |
| `src/components/search/SavedSearchesPanel.tsx` | Updated navigation to `/advanced-search` |
| `src/pages/Search.tsx` | Fixed filter overflow, added contract click handler |

---

## Testing

### Filter Layout Verification

1. Navigate to `/advanced-search`
2. Verify filter chips are organized in rows by type (Severity, Scanners, Categories)
3. Resize window to narrow width
4. Verify chips wrap to new lines without overflow
5. Verify no horizontal scrollbar appears
6. Verify filters don't go behind Saved Searches section

### Dark Mode Verification

1. Enable dark mode
2. Navigate to `/advanced-search`
3. Verify filter section labels are readable
4. Verify active/inactive chip states have proper contrast

---

## Impact

- **User Impact**: Improved usability of Advanced Search page on narrower screens
- **Breaking Changes**: None (route change has no backward compatibility redirect)
- **Performance**: No performance impact

---

## Deployment

```bash
# Build dashboard image in minikube context
eval $(minikube docker-env)
docker build --no-cache \
  --build-arg VITE_SUPABASE_URL=... \
  --build-arg VITE_SUPABASE_ANON_KEY=... \
  -t blocksecops-dashboard:0.29.0 \
  -f blocksecops-dashboard/Dockerfile .

# Deploy
kubectl rollout restart deployment/dashboard -n dashboard-local
```

---

## Related Documentation

- Feature Test: [25-dark-mode-global-search.md](../feature-tests/25-dark-mode-global-search.md) (Test 12 added)
- Feature Test: [40-quality-gates.md](../feature-tests/40-quality-gates.md)
- Plan: [humble-bubbling-rabin.md](../../.claude/plans/humble-bubbling-rabin.md)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 0.29.0 | 2026-01-13 | QualityGatePanel integration, search improvements, filter layout fix |
| 0.28.0 | 2026-01-12 | Economic Security panel integration |
| 0.27.1 | 2026-01-11 | Previous release |
