# ConfigMap Symlink Scanner Fix Verification

**Priority**: P0 - Critical
**Date**: February 17, 2026
**Services**: tool-integration (all 15 scanner images)

---

## Overview

All 15 scanner wrapper scripts were fixed to use `find -L` (follow symlinks) when discovering contract files in `/contracts/`. Without this flag, scanners found 0 files when contracts were mounted via Kubernetes ConfigMap volumes, because ConfigMap volumes use hidden-directory symlinks internally.

Additionally, all wrappers now filter hidden directory paths (`-not -path '*/\.*'`) to prevent duplicate findings from ConfigMap's internal symlink structure.

---

## Root Cause

Kubernetes ConfigMap volumes create a symlink structure:

```
/contracts/
  ..data -> ..2026_02_17_123456.789/
  ..2026_02_17_123456.789/
    contract.sol
  contract.sol -> ..data/contract.sol
```

The `find` command without `-L` does not follow symlinks, so `find /contracts -name "*.sol"` returns nothing when the actual file is behind a symlink chain.

---

## Scanners Fixed

| Scanner | Image Version | File Modified |
|---------|--------------|---------------|
| slither | 0.3.3 | `run-slither.sh` |
| aderyn | 0.7.3 | `run-aderyn.sh` |
| semgrep | 0.3.8 | `semgrep-scan` |
| solhint | 0.1.7 | `solhint-scan` |
| vyper | 0.3.1 | `run-vyper.sh` |
| moccasin | 0.3.1 | `run-moccasin.sh` |
| halmos | 0.3.1 | `halmos-scan` |
| echidna | 0.3.2 | `Dockerfile` (embedded entrypoint) |
| medusa | 0.3.2 | `medusa-scan` |
| wake | 0.3.8 | `wake-scan` |
| soliditydefend | 0.9.1 | `soliditydefend-scan` |
| sol-azy | 0.4.2 | `Dockerfile` (embedded entrypoint) |
| cargo-fuzz-solana | 0.3.1 | `Dockerfile` (embedded entrypoint) |
| trident | 0.3.1 | `Dockerfile` (embedded entrypoint) |
| rustdefend | 0.4.0 | Tool v0.4.0 title field, FP fixes, clean slate upgrade |

---

## Test Plan

### Pre-requisites
- All 15 scanner images built and pushed to Harbor
- tool-integration ConfigMap updated and deployment restarted

### Test 1: Vyper Scanner (was broken, 0 findings)
1. Navigate to a Vyper contract (e.g., `reentrancy.vy`)
2. Trigger a scan with `vyper` scanner
3. **Expected:** Scan completes with findings (was returning 0 before fix)

### Test 2: SolidityDefend Code Snippets
1. Trigger a SolidityDefend scan on any Solidity contract
2. Check vulnerability detail page
3. **Expected:** Code snippets appear in findings (new post-processing extracts snippets from source files)
4. **Expected:** AI Generated Repair feature works (requires code snippet)

### Test 3: RustDefend Vulnerability Names
1. Trigger a RustDefend scan on a Rust contract
2. Check vulnerability list
3. **Expected:** Vulnerability titles show descriptive names (not detector IDs like "SOL-002")
4. Note: Previous RustDefend findings/scans were cleaned from database for clean ML data

### Test 4: Existing Solidity Scanners (regression)
1. Trigger a full scan on any Solidity contract
2. **Expected:** All scanners produce findings as before
3. **Expected:** No duplicate findings from hidden directory paths

### Test 5: Scan Deletion
1. Navigate to a contract detail page
2. Select a scan and click Delete
3. **Expected:** Scan is deleted (was broken before dedup FK fix)

---

## Verification Commands

```bash
# Check all scanner images are available in Harbor
for scanner in slither aderyn semgrep solhint vyper moccasin halmos echidna medusa wake soliditydefend sol-azy cargo-fuzz-solana trident rustdefend; do
  echo -n "$scanner: "
  curl -sk "https://harbor.blocksecops.local/api/v2.0/projects/blocksecops/repositories/scanner-${scanner}/artifacts" | jq -r '.[0].tags[0].name' 2>/dev/null || echo "NOT FOUND"
done

# Verify tool-integration has updated ConfigMap
kubectl exec -n tool-integration-local deployment/tool-integration -- \
  env | grep SCANNER_IMAGE | sort

# Check API service has updated ConfigMap
kubectl exec -n api-service-local deployment/api-service -- \
  env | grep SCANNER_IMAGE | sort
```
