# Changelog: Dashboard v0.45.13 — Contracts Column Toggles

**Date:** 2026-02-19
**Service:** dashboard
**Version:** 0.45.12 → 0.45.13

## Summary

The contracts table at `/contracts` had 12 columns that pushed the Scan and Delete action buttons off-screen. This release adds a column toggle system that defaults to a minimal 3-column view (checkbox, contract name, actions) with the ability to show/hide 8 optional columns via a dropdown.

## Changes

### Column Toggle System (`ContractsList.tsx`)

**New UI: "Columns" dropdown button**
- Positioned between the search input and language filter
- Shows checkboxes for 8 optional columns
- Badge indicator shows count of enabled columns
- "Show All" / "Hide All" buttons at the bottom of the dropdown
- Closes on click outside

**Always-visible columns (not toggleable):**
- Checkbox (row selection)
- Contract (name + address)
- Actions (Scan + Delete)

**Optional columns (toggleable, OFF by default):**
- Projects
- Tags
- Type (Framework)
- Language
- Network
- Lines of Code
- Status
- Created

**Persistence:**
- Column visibility preferences saved to `localStorage` under key `contracts-visible-columns`
- Preferences survive page reloads and browser sessions

**Table layout improvements:**
- Removed `table-fixed` class — columns now auto-size based on content
- Removed `<colgroup>` with fixed widths
- Reduced cell padding from `px-6 py-4` to `px-4 py-3` for a more compact layout
- Removed the redundant "View →" column (entire row is already clickable)
- Kept `overflow-x-auto` for horizontal scrolling when many columns are enabled

**Compact action buttons:**
- Scan and Delete buttons are now icon-only (no text labels)
- Tooltips via `title` attribute provide context on hover
- Button size reduced to `h-8 w-8` squares
- Action column footprint reduced significantly

## Files Modified

| File | Change |
|------|--------|
| `src/pages/ContractsList.tsx` | Column toggle system, compact layout, icon-only actions |
| `package.json` | Version 0.45.12 → 0.45.13 |
| `k8s/overlays/local/kustomization.yaml` | newTag + version label → 0.45.13 |

## Database

No database changes required. Column visibility is stored client-side in localStorage.

## Deployment

1. Build dashboard image at version 0.45.13
2. Push to Harbor registry
3. Apply kustomization: `kubectl apply -k blocksecops-dashboard/k8s/overlays/local/`
4. Restart dashboard pod: `kubectl rollout restart deployment/dashboard -n dashboard-local`
