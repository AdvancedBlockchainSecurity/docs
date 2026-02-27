# Scanner Audit Fix Verification

**Priority**: P0 - Critical
**Date**: February 17, 2026
**Services**: tool-integration, api-service

---

## Overview

Production fixes for 4 scanner audit issues: solhint 0 vulnerabilities, vyper scanner_id misattribution, stuck contracts in "scanning" status, and canary CronJob 422 errors. Plus code snippet extraction fallback for AI Code Repair.

---

## Test 1: Solhint Produces Findings (P0)

**Validates:** Solhint scanner extracts and stores vulnerabilities.

1. Upload a Solidity contract (e.g., VulnerableDeFiVault.sol)
2. Trigger a scan with solhint scanner
3. **Expected:** Scan completes with >0 findings in database
4. **Expected:** `scanner_id` = "solhint" on all findings
5. **Regression:** Previously, 43 scans completed with 0 findings stored

```bash
# Check findings count for latest solhint scan
curl -sk https://app.0xapogee.local/api/v1/vulnerabilities?scanner_id=solhint | jq '.total'
# Should be > 0

# Check tool-integration logs for extraction
kubectl logs -n tool-integration-local deployment/tool-integration --tail=50 | grep -i "solhint"
# Should show "Transformed N findings from solhint output" (N > 0)
```

- [ ] Solhint scan completes successfully
- [ ] >0 vulnerabilities stored in database
- [ ] Findings have correct scanner_id "solhint"
- [ ] No "WARNING: 0 findings were extracted" in logs

---

## Test 2: Vyper Findings Attributed Correctly (P1)

**Validates:** Vyper scanner findings have `scanner_id: "vyper"`, not detector-specific IDs.

1. Upload a Vyper contract (e.g., VulnerableStorage.vy)
2. Trigger a scan with vyper scanner
3. **Expected:** Findings have `scanner_id: "vyper"`
4. **Regression:** Previously, findings had detector-specific IDs from SlitherParser

```bash
# Check scanner_id on vyper findings
curl -sk https://app.0xapogee.local/api/v1/vulnerabilities?scanner_id=vyper | jq '.total'

# Verify no findings attributed to detector IDs instead of "vyper"
kubectl logs -n tool-integration-local deployment/tool-integration --tail=50 | grep "Vyper scan"
# Should show "Slither returned N detectors from preprocessed Vyper code"
```

- [ ] Vyper scan completes successfully
- [ ] All findings have `scanner_id: "vyper"`
- [ ] No findings have detector-specific scanner_id (e.g., "reentrancy-eth")
- [ ] Detector count logged in tool-integration

---

## Test 3: No Stuck Contracts in "scanning" (P0)

**Validates:** Contracts no longer get stuck in "scanning" status.

1. Run the stale scan recovery endpoint
2. Verify 0 contracts remain stuck
3. Trigger a scan and kill the scanner pod mid-execution
4. **Expected:** After 1 hour, the scan is marked "failed" and contract status resets

```bash
# Check for stuck contracts
PGPASSWORD=postgres psql -h 127.0.0.1 -p 5432 -U postgres -d solidity_security \
  -c "SELECT count(*) FROM contracts WHERE status = 'scanning' AND id NOT IN (SELECT DISTINCT contract_id FROM scans WHERE status IN ('queued', 'running'));"
# Should return 0

# Trigger recovery endpoint (requires internal service auth)
curl -sk -X POST https://app.0xapogee.local/api/v1/scans/maintenance/recover-stale-scans \
  -H "X-Internal-Service: true"
```

- [ ] Data fix SQL applied for existing stuck contracts
- [ ] Recovery endpoint returns successfully
- [ ] 0 contracts stuck in "scanning" with no active scans
- [ ] New stuck contracts recovered after 1 hour

---

## Test 4: Canary CronJob No 422 Errors (P1)

**Validates:** Canary health check uses valid UUID, no more 422 rejections.

1. Wait for next canary CronJob execution (runs on schedule)
2. Check tool-integration logs for 422 errors

```bash
# Check recent canary jobs
kubectl get jobs -n tool-integration-local | grep canary | tail -5

# Check for 422 errors in tool-integration logs
kubectl logs -n tool-integration-local deployment/tool-integration --tail=100 | grep -i "422\|canary"
# Should NOT show any 422 errors from canary
```

- [ ] Canary CronJob completes without 422 errors
- [ ] Scan ID in canary request is a valid UUID format

---

## Test 5: Code Snippet on Vulnerability Detail (P1)

**Validates:** Vulnerability detail page shows code snippet and enables AI Code Repair.

1. Trigger a new scan on any contract
2. Navigate to a vulnerability with a line_number
3. **Expected:** Code Location section visible with source code context
4. **Expected:** "Generate AI Repair" button is enabled (not grayed out)

```bash
# Check a vulnerability has code_snippet populated
curl -sk https://app.0xapogee.local/api/v1/vulnerabilities?limit=5 | jq '.items[0].code_snippet'
# Should NOT be null for vulnerabilities with line_number
```

- [ ] New vulnerabilities have code_snippet populated
- [ ] Code Location section visible on vulnerability detail page
- [ ] Arrow marker points to the correct line
- [ ] "Generate AI Repair" button is enabled
