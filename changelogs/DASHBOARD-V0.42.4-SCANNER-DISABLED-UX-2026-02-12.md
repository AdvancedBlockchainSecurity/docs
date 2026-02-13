# Dashboard v0.42.4 - Scanner Disabled UX Improvement

**Date:** February 12, 2026
**Component:** blocksecops-dashboard
**Version:** 0.42.3 → 0.42.4
**PR:** #141

---

## Summary

Project-required scanners (fuzzers, symbolic execution) are now **visible but greyed out and disabled** on single-file contracts instead of being hidden entirely. This gives users full visibility into the platform's scanner capabilities while preventing incompatible selections.

---

## What Changed

| Behavior | Before (v0.42.3) | After (v0.42.4) |
|----------|-------------------|------------------|
| Project-required scanners | Hidden from list | Visible, greyed out with "Requires Project" badge |
| Checkbox | N/A (scanners hidden) | Disabled, not clickable |
| Row styling | N/A | opacity-50, cursor-not-allowed |
| Select All | Selected all visible | Skips disabled scanners |
| Presets | Applied to all visible | Excludes disabled scanners |
| Counter | "X of Y" (Y = all visible) | "X of Y" (Y = selectable only) |
| Category counter | All in category | Selectable in category only |

### Affected Scanners (on single-file contracts)

| Scanner | Category | `requires_project` |
|---------|----------|-------------------|
| Echidna | Fuzzing | true |
| Medusa | Fuzzing | true |
| Moccasin | Fuzzing | true |
| Halmos | Symbolic Execution | true |
| Trident | Fuzzing (Solana) | true |
| cargo-fuzz-solana | Fuzzing (Solana) | true |
| sec3-xray | Static Analysis (Solana) | true |

---

## Files Modified

| File | Change |
|------|--------|
| `src/components/scanner/ScannerSelector.tsx` | Added disabled state, guard logic, filtered counters |
| `package.json` | 0.42.3 → 0.42.4 |
| `k8s/overlays/local/kustomization.yaml` | newTag + version label → 0.42.4 |

---

## Technical Details

### ScannerSelector.tsx Changes

1. **`selectableScanners` memo** — Filters scanners to only those where `isProject || !scanner.requires_project`
2. **`handleScannerToggle` guard** — Returns early if scanner is project-required on single-file contract
3. **`handlePresetSelect` filter** — Removes project-required scanner IDs from preset selections
4. **`handleSelectAll`** — Uses `selectableScanners` instead of `scanners`
5. **Row styling** — `needsProject ? 'opacity-50 cursor-not-allowed' : ...`
6. **Checkbox** — `disabled={needsProject}` with muted styling
7. **Label** — Muted text color and `cursor-not-allowed` when disabled

---

## Verification

1. Open scanner selector with a single-file Solidity contract
2. Verify fuzzers (echidna, medusa) and symbolic (halmos) are greyed out
3. Verify "Requires Project" amber badge is shown
4. Click "Select All" — disabled scanners not selected
5. Try clicking a greyed-out scanner — should not toggle
6. Upload a project — all scanners enabled and selectable
