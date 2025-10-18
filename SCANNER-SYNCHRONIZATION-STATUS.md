# Scanner Data Synchronization Status

**Last Updated:** October 17, 2025
**Phase:** Phase 3 - Scanner Selection Integration

---

## Overview

This document tracks the synchronization status of scanner metadata across the platform's three data sources:

1. **Backend API** (`/api/v1/scanners`) - Source of truth
2. **UI Core Package** (`@blocksecops/ui-core`) - Shared component library
3. **Dashboard Constants** (`src/lib/constants/scanners.ts`) - DEPRECATED

---

## Current Status Summary

| Source | Total Scanners | Solidity | Vyper | Rust | Move | Cairo | Status |
|--------|----------------|----------|-------|------|------|-------|--------|
| **Backend API** | **21** | 10 | 2 | 4 | 2 | 3 | ✅ Production |
| **UI Core** | **27** | 10 | 2 | 7 | 3 | 3 | ⚠️ Partially synced |
| **Dashboard** | **12** | 7 | 1 | 2 | 1 | 1 | ❌ DEPRECATED |

### Scanner Count Breakdown

**Backend API (21 scanners):**
- Solidity: 10 (slither, aderyn, mythril, semgrep, solhint, 4naly3er, halmos, echidna, manticore, certora)
- Vyper: 2 (vyper, moccasin)
- Rust/Solana: 4 (sol-azy, sec3-xray, cargo-fuzz-solana, trident)
- Move: 2 (move-prover, cargo-fuzz-move)
- Cairo: 3 (caracal, starknet-foundry, tayt)

**UI Core (27 scanners):**
- Has 6 additional tools not in backend:
  - `anchor-verify` (Rust)
  - `rust-clippy` (Rust)
  - `soteria` (Rust)
  - `movesmith` (Move)
  - `slither-vyper` (Vyper - duplicate of `vyper`)
  - Non-tool IDs: `quick`, `standard`, `deep`, `custom` (preset IDs mixed in)

---

## Synchronization Analysis

### ✅ Fully Synchronized (Solidity)
All 10 Solidity tools match perfectly between backend and UI Core:
- slither ✓
- aderyn ✓
- mythril ✓
- semgrep ✓
- solhint ✓
- 4naly3er ✓
- halmos ✓
- echidna ✓
- manticore ✓
- certora ✓

### ⚠️ Partially Synchronized (Vyper, Rust, Move, Cairo)

**Vyper (2 backend, 2 ui-core):**
- Backend has: `vyper`, `moccasin`
- UI Core has: `slither-vyper`, `moccasin`
- **Issue:** Different IDs for same tool (vyper vs slither-vyper)

**Rust/Solana (4 backend, 7 ui-core):**
- Missing in backend: `anchor-verify`, `rust-clippy`, `soteria`
- Backend has all 4 core Rust scanners

**Move (2 backend, 3 ui-core):**
- Missing in backend: `movesmith`
- Both have: `move-prover`, `cargo-fuzz-move`

**Cairo (3 backend, 3 ui-core):**
- ✅ Fully matched: `caracal`, `starknet-foundry`, `tayt`

---

## Integration Impact

### Phase 3 Scanner Selection (✅ Complete)

The ContractDetail page now:
1. ✅ Fetches scanners from backend API dynamically
2. ✅ Filters by contract language (e.g., only shows 10 Solidity tools for Solidity contracts)
3. ✅ Transforms backend data to ui-core Tool format
4. ✅ Passes transformed data to ScanConfigurationModal

**Result:** Modal displays backend's 21 scanners (filtered by language) instead of ui-core's hardcoded 27 tools.

### Deprecated Dashboard Constants

The file `/src/lib/constants/scanners.ts` is:
- ✅ Marked as deprecated with migration guide
- ✅ No longer imported by any dashboard code
- 📅 Scheduled for removal in Phase 4 (Q1 2026)

---

## Recommendations

### Priority 1: Backend Scanner Registry
- ✅ **DONE:** Backend API is the source of truth
- ✅ **DONE:** Dashboard fetches from API dynamically
- ⏳ **TODO:** Add missing Rust tools to backend (`anchor-verify`, `rust-clippy`, `soteria`)
- ⏳ **TODO:** Add `movesmith` to backend Move scanners
- ⏳ **TODO:** Standardize Vyper scanner ID (`vyper` vs `slither-vyper`)

### Priority 2: UI Core Alignment
- ⏳ **TODO:** Update ui-core toolsMetadata.ts to match backend exactly
- ⏳ **TODO:** Remove non-scanner IDs from TOOLS array (`quick`, `standard`, `deep`, `custom`)
- ⏳ **TODO:** Create sync script to keep ui-core and backend in sync

### Priority 3: Data Governance
- ⏳ **TODO:** Establish single source of truth for scanner metadata (backend database)
- ⏳ **TODO:** Create CI/CD check to validate scanner metadata consistency
- ⏳ **TODO:** Document scanner addition/removal process

---

## Migration Notes

### For Dashboard Developers
✅ **Use API instead of constants:**
```typescript
// ❌ Old (deprecated)
import { SCANNER_TOOLS } from '../lib/constants/scanners';

// ✅ New (recommended)
import { listScanners } from '../lib/api/scanners';
const { data } = useQuery({
  queryKey: ['scanners', language],
  queryFn: () => listScanners(language)
});
```

### For Backend Developers
When adding a new scanner:
1. Add to backend scanner registry (database or config)
2. Ensure `/api/v1/scanners` endpoint returns it
3. Update ui-core `toolsMetadata.ts` (until sync script exists)
4. Test in dashboard scanner selection modal

---

## Related Documents

- [Phase 3 Scanner Selection Status](/Users/pwner/Git/ABS/TaskDocs-BlockSecOps/blocksecops/PHASE-3-SCANNER-SELECTION-STATUS.md)
- [Platform Development Standards](/Users/pwner/Git/ABS/docs/PLATFORM-DEVELOPMENT-STANDARDS.md)
- [Scanner API Documentation](/Users/pwner/Git/ABS/blocksecops-api-service/docs/api/scanners.md)

---

## Change Log

### 2025-10-17
- ✅ Completed Phase 3 scanner selection integration
- ✅ Dashboard now fetches from API instead of hardcoded constants
- ✅ Documented synchronization status across all three sources
- ✅ Deprecated `/src/lib/constants/scanners.ts` with migration guide
