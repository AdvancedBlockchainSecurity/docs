# Scanner Reliability & Vulnerability API Fix Verification

**Priority**: P0 - Critical / P1 - High
**Date**: February 17, 2026
**Services**: tool-integration, api-service

---

## Overview

Production fixes for 5 bugs: ConfigMap race condition destroying concurrent scanner mounts, insufficient job timeouts killing scanners before completion, RustDefend wrapper temp file leaks and curl error masking, and non-functional vulnerability API `contract_id`/`scan_id` filters.

---

## Test Plan

### Test 1: ConfigMap Race Condition (P0)

**Validates:** Concurrent scanners no longer destroy each other's ConfigMap mounts.

1. Upload a Solidity contract
2. Trigger a scan with multiple scanners (e.g., slither + aderyn + semgrep)
3. **Expected:** All scanners complete successfully
4. **Expected:** No scanner logs show "empty /source directory" or "0 files found"
5. **Regression:** Previously, the second scanner's ConfigMap creation would delete and recreate, destroying the first scanner's mount

```bash
# Verify no ConfigMap deletion events
kubectl get events -n tool-integration-local --field-selector reason=Killing | grep configmap
# Should return empty
```

### Test 2: RustDefend Completes Within Timeout (P1)

**Validates:** RustDefend jobs complete within the 300s timeout.

1. Upload a Rust/Solana contract (e.g., Solana Vault)
2. Trigger a scan with rustdefend scanner
3. **Expected:** Scan completes with findings (>0 vulnerabilities)
4. **Expected:** No Kubernetes job timeout (activeDeadlineSeconds)
5. **Regression:** Previously returned 0 findings because job was killed at 120s

```bash
# Check rustdefend job didn't hit deadline
kubectl get jobs -n tool-integration-local -l scanner=rustdefend --sort-by=.metadata.creationTimestamp | tail -5
# Should show "Complete" status, not "DeadlineExceeded"
```

### Test 3: Scanner Timeout Validation (P1)

**Validates:** No scanner has a timeout below 180s.

```bash
# Unit test covers this
cd /home/pwner/Git/blocksecops-tool-integration
python3 -m pytest tests/unit/scanners/test_job_timeouts.py -v
# All 20 tests should pass
```

### Test 4: Vulnerability API Filtering (P0)

**Validates:** `contract_id` and `scan_id` query params filter results.

```bash
# Get a contract ID from the database
CONTRACT_ID="ea2f0908-8f61-4edf-b735-a90e7c58329c"

# Filter by contract_id
curl -s -k "https://app.0xapogee.com/api/v1/vulnerabilities?contract_id=${CONTRACT_ID}" \
  -H "Authorization: Bearer $TOKEN" | jq '.total'
# Expected: Returns only vulnerabilities for that contract

# Filter by invalid UUID
curl -s -k "https://app.0xapogee.com/api/v1/vulnerabilities?contract_id=not-a-uuid" \
  -H "Authorization: Bearer $TOKEN"
# Expected: 400 Bad Request with "Invalid contract_id format (must be UUID)"

# No filter (backwards compatibility)
curl -s -k "https://app.0xapogee.com/api/v1/vulnerabilities" \
  -H "Authorization: Bearer $TOKEN" | jq '.total'
# Expected: Returns all vulnerabilities for the org
```

### Test 5: RustDefend Detector ID Normalization (P2)

**Validates:** Detector IDs are stored in canonical uppercase-dash format.

1. Trigger a RustDefend scan
2. Query vulnerabilities for that scan
3. **Expected:** All `vulnerability_type` values use format like `SOL-003`, not `sol_003` or `SOL 003`

```bash
# Check vulnerability types for a rustdefend scan
SCAN_ID="<scan_id>"
curl -s -k "https://app.0xapogee.com/api/v1/vulnerabilities?scan_id=${SCAN_ID}" \
  -H "Authorization: Bearer $TOKEN" | jq '.items[].vulnerability_type'
# Expected: All values match pattern [A-Z]+-[A-Z0-9-]+
```

### Test 6: Unit Tests Pass

```bash
# ConfigMap race condition tests
cd /home/pwner/Git/blocksecops-tool-integration
python3 -m pytest tests/unit/scanners/test_configmap_race.py -v
# Expected: 5 tests pass

# Timeout validation tests
python3 -m pytest tests/unit/scanners/test_job_timeouts.py -v
# Expected: 20 tests pass

# Vulnerability filter tests
cd /home/pwner/Git/blocksecops-api-service
python3 -m pytest tests/unit/test_vulnerability_filters.py -v -o "addopts="
# Expected: 10 tests pass
```

---

## Verification Commands

```bash
# Check scanner image versions in ConfigMap
kubectl exec -n tool-integration-local deployment/tool-integration -- \
  env | grep SCANNER_IMAGE_RUSTDEFEND
# Expected: scanner-rustdefend:0.3.3 (or Harbor/GCP prefixed)

# Verify RustDefend job timeout in KJM source
grep -A2 '"rustdefend"' /home/pwner/Git/blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py | grep timeout
# Expected: 300

# Verify ConfigMap race fix
grep -A3 'status == 409' /home/pwner/Git/blocksecops-tool-integration/src/scanners/kubernetes_job_manager.py
# Expected: "reusing" log message, no delete_namespaced_config_map call
```
