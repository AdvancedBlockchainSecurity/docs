# Scanning Tests

**Priority**: P0 - Critical
**Last Tested**: December 29, 2025
**Endpoint**: `POST /api/v1/scans`

---

## 1. Trigger Scan

### 1.1 Basic Scan Trigger
- [ ] Scan triggered on uploaded contract
- [ ] Scan ID returned in response
- [ ] Scan status = "queued" initially
- [ ] Contract status updated to "scanning"

### 1.2 Scan with Scanner Selection
- [ ] Scan with single scanner specified
- [ ] Scan with multiple scanners specified
- [ ] Default scanners used when none specified
- [ ] Invalid scanner name rejected

### 1.3 Scan Prerequisites
- [ ] Can't scan non-existent contract (404)
- [ ] Can't scan without authentication (401)
- [ ] Can't scan other user's contract (403)
- [ ] Quota checked before scan starts

---

## 2. Scan Status

### 2.1 Status Transitions
- [ ] queued → running → completed
- [ ] queued → running → failed (on error)
- [ ] Status updates visible via API
- [ ] Status updates visible in UI

### 2.2 Status Polling
- [ ] GET /api/v1/scans/{id} returns current status
- [ ] Progress percentage shown (if available)
- [ ] Estimated time remaining (if available)

---

## 3. Scanner Selection

> **Per-scanner validation tests**: See [22-scanner-validation.md](./22-scanner-validation.md)

### 3.1 Scanner Availability
- [ ] 17 scanners registered in orchestration
- [ ] Scanner list matches tier capabilities
- [ ] All scanner images present in minikube

### 3.2 Scanner Compatibility
- [ ] Only compatible scanners shown per language
- [ ] Solidity scanners for .sol files
- [ ] Vyper scanners for .vy files
- [ ] Rust scanners for .rs files
- [ ] Invalid scanner + language combo rejected

---

## 4. Scan Results

### 4.1 Results Availability
- [ ] Results available after scan completes
- [ ] GET /api/v1/scans/{id}/results returns findings
- [ ] Results stored in database
- [ ] Results associated with correct contract

### 4.2 Finding Structure
- [ ] Vulnerability type/name
- [ ] Severity (critical, high, medium, low, info)
- [ ] File path where found
- [ ] Line number(s)
- [ ] Description/message
- [ ] Recommendation (if available)

### 4.3 Multi-Scanner Results
- [ ] Results from all scanners combined
- [ ] Scanner source identified per finding
- [ ] Duplicate findings deduplicated
- [ ] Confidence scores shown

---

## 5. Scan Priority Queue

### 5.1 Tier-Based Priority
- [ ] Enterprise scans: priority 1 (highest)
- [ ] Pro scans: priority 2
- [ ] Free scans: priority 3 (lowest)
- [ ] Higher priority scans processed first

### 5.2 Queue Visibility
- [ ] Queue position shown to user
- [ ] Estimated wait time shown
- [ ] Queue updates in real-time

---

## 6. Multi-File Scanning

### 6.1 Archive Scanning
- [ ] All files in archive scanned
- [ ] Main file identified correctly
- [ ] Import dependencies included
- [ ] Results reference correct file paths

### 6.2 Framework-Aware Scanning
- [ ] Foundry projects scanned correctly
- [ ] Hardhat projects scanned correctly
- [ ] Remappings applied during scan
- [ ] Dependencies available to scanner

---

## 7. Scan History

- [ ] Scan history visible per contract
- [ ] Previous scan results accessible
- [ ] Scan comparison possible (if implemented)
- [ ] Scan history sorted by date

---

## 7.5 Scan Deletion

### 7.5.1 Single Scan Deletion (ScanResults page)
- [ ] "Delete Scan" button visible on scan results page
- [ ] Confirmation dialog appears before deletion
- [ ] Dialog shows warning about cascade deletion (vulnerabilities, specialized results)
- [ ] Scan deleted from database after confirmation
- [ ] Associated vulnerabilities deleted (cascade)
- [ ] User redirected to contract page after deletion
- [ ] Scan no longer appears in contract's scan history

### 7.5.2 Batch Scan Deletion (ContractDetail page)
- [ ] Checkboxes visible in Recent Scans table
- [ ] "Select All" checkbox works correctly
- [ ] Indeterminate state shown when some selected
- [ ] "Delete Selected" button appears when scans selected
- [ ] Confirmation dialog shows count of scans to delete
- [ ] All selected scans deleted from database
- [ ] Table refreshes after deletion
- [ ] Selection cleared after deletion

### 7.5.3 Deletion Authorization
- [ ] Can only delete own scans (403 for others)
- [ ] Non-existent scan returns 404
- [ ] Unauthenticated request returns 401

### 7.5.4 Database Verification
- [ ] Scan record removed from `scans` table
- [ ] Related vulnerabilities removed from `vulnerabilities` table
- [ ] Specialized results removed (code_quality, gas_analysis, etc.)
- [ ] Payment/credit transactions preserved (scan_id set to NULL)

---

## 8. Scan Quotas

- [ ] Scan count incremented on trigger
- [ ] Quota checked before scan
- [ ] Scan blocked when quota exhausted
- [ ] Error message shows upgrade path

---

## 9. Scan Errors

### 9.1 Scanner Errors
- [ ] Scanner timeout handled gracefully
- [ ] Scanner crash doesn't break system
- [ ] Partial results saved on failure
- [ ] Error message shown to user

### 9.2 Contract Errors
- [ ] Compilation errors reported
- [ ] Syntax errors in contract reported
- [ ] Missing imports reported

---

## 10. UI Integration

### 10.1 Scan Button
- [ ] Scan button visible on contract page
- [ ] Scan button disabled while scanning
- [ ] Scanner selection available

### 10.2 Results Display
- [ ] Results page loads after scan
- [ ] Findings grouped by severity
- [ ] Findings expandable for details
- [ ] Line numbers clickable (to source)

---

## 11. Scanner Pattern Coverage

**Last Validated:** December 21, 2025
**Status:** ✅ All Tests Passed

### 11.1 Pattern Database Integrity
- [x] No duplicate pattern IDs in vulnerability_patterns.json ✅
- [x] Pattern count >= 397 (actual: 397) ✅
- [x] Mapping count >= 638 (actual: 638) ✅
- [x] No orphan mappings (mappings referencing non-existent patterns) ✅

### 11.2 Scanner Registry
- [x] All 17 scanner executors registered ✅
- [x] All 15 scanner Dockerfiles present ✅
- [x] Scanner IDs match pattern mappings ✅

### 11.3 Verification Script
- [x] Run `/scripts/verify-scanner-coverage.sh` ✅
- [x] All critical checks pass (0 errors) ✅
- [x] Parser tests pass (27/27) ✅

**Validation Reference:** See `/TaskDocs-BlockSecOps/phases/02-phase-3.1-scanner-integration/SCANNER-AUDIT-VALIDATION-CHECKLIST.md`

---

## Test Scenarios

### Quick Scan Test
1. Upload simple .sol file
2. Trigger scan with Slither
3. Wait for completion
4. Verify results

### Multi-Scanner Test
1. Upload contract
2. Trigger scan with Slither + Aderyn
3. Verify combined results
4. Check deduplication

### Framework Scan Test
1. Upload Foundry project with OZ
2. Trigger scan
3. Verify all imports resolved
4. Check scan completes without errors

---

## Test Notes

_Record scanning test results here:_

```
[Date] | [Scanner] | [Contract Type] | [Result] | [Notes]
2025-12-23 | sol-azy | Rust/Solana | PASS | Vulnerabilities detected and displayed in dashboard
2025-12-22 | sol-azy | Rust/Solana | PASS | Dashboard auto-selects based on language
2025-12-22 | vyper | Vyper | PASS | Dashboard auto-selects based on language
2025-12-22 | soliditydefend | Solidity | PASS | Default for Solidity contracts
```

### Phase 3.5 Bug Fixes (2025-12-22/23)
- **Dashboard**: Language-based scanner selection in `handleTriggerScan` (PR #76)
- **Tool Integration**: Vyper/Solana scanners registered in `valid_scanners` (PR #60)
- **Scanner Mappings**: Fixed `sol-azy` ID in kubernetes_job_manager.py
- **Sol-azy Callback (2025-12-23)**: Added HTTP callback mechanism, fixed severity case for PostgreSQL
- **File Extension Detection (2025-12-23)**: Rust/Vyper patterns detected, ConfigMap files named correctly
- **K8s Job Env Vars (2025-12-23)**: Added CONTRACTS_DIR and OUTPUT_DIR to scanner jobs

---

## 12. Fuzzer Scanner Filtering (December 29, 2025)

**Status:** ✅ Implemented
**API Version:** 0.6.2
**Dashboard Version:** 0.17.1

### 12.1 Single-File Upload (Fuzzers Hidden)

Fuzzers require project structure with test harnesses to provide meaningful results. They are hidden from single-file uploads.

- [x] Upload .sol file → Echidna NOT in scanner list ✅ (verified 2025-12-29)
- [x] Upload .sol file → Medusa NOT in scanner list ✅ (verified 2025-12-29)
- [x] Upload .sol file → Halmos NOT in scanner list ✅ (verified 2025-12-29)
- [x] Upload .vy file → Moccasin NOT in scanner list ✅ (verified 2025-12-29)
- [x] Upload .rs file → Trident NOT in scanner list ✅ (verified 2025-12-29)
- [x] Upload .rs file → cargo-fuzz-solana NOT in scanner list ✅ (verified 2025-12-29)
- [x] Upload .rs file → sec3-xray NOT in scanner list ✅ (verified 2025-12-29)

**API Verification:**
```bash
curl "http://api-service:8000/api/v1/scanners?is_project=false"
# Should return 8 scanners (no fuzzers)
```

### 12.2 Project Upload (Fuzzers Shown)

- [x] Upload Foundry ZIP → Echidna in scanner list ✅ (verified 2025-12-29)
- [x] Upload Foundry ZIP → Medusa in scanner list ✅ (verified 2025-12-29)
- [x] Upload Foundry ZIP → Halmos in scanner list ✅ (verified 2025-12-29)
- [ ] Upload Moccasin project → Moccasin in scanner list (not tested - no Moccasin project available)
- [ ] Upload Anchor project → Trident in scanner list (not tested - no Anchor project available)
- [ ] Upload Anchor project → cargo-fuzz-solana in scanner list (not tested - no Anchor project available)

**API Verification:**
```bash
curl "http://api-service:8000/api/v1/scanners?is_project=true"
# Should return 15 scanners (including fuzzers)
```

### 12.3 Scanner Metadata

- [x] `requires_project` field present on all scanners ✅ (verified 2025-12-29)
- [x] Echidna: `requires_project=true` ✅ (verified 2025-12-29)
- [x] Medusa: `requires_project=true` ✅ (verified 2025-12-29)
- [x] Moccasin: `requires_project=true` ✅ (verified 2025-12-29)
- [x] Halmos: `requires_project=true` ✅ (verified 2025-12-29)
- [x] Slither: `requires_project=false` ✅ (verified 2025-12-29)
- [x] Aderyn: `requires_project=false` ✅ (verified 2025-12-29)

**API Verification:**
```bash
curl "http://api-service:8000/api/v1/scanners/echidna" | jq '.requires_project'
# Should return: true
```

### 12.4 Preset Filtering

- [x] GET /scanners/presets/solidity?is_project=false excludes fuzzers from all presets ✅ (verified 2025-12-29)
- [x] GET /scanners/presets/solidity?is_project=true includes fuzzers in Standard/Deep presets ✅ (verified 2025-12-29)
- [x] Quick preset always uses static analyzers only ✅ (verified 2025-12-29)
- [x] Deep preset includes halmos, echidna, medusa for projects ✅ (verified 2025-12-29)

### 12.5 Dashboard UI

- [x] Single-file contract: ScannerSelector shows informational notice about fuzzer requirements ✅ (code verified)
- [x] Project upload: All scanners visible including fuzzers ✅ (verified 2025-12-29)
- [ ] Scanner categories visible (static, fuzzing, symbolic, linting) (UI not manually tested)

### 12.6 Fuzzing Results Display

**Status:** ✅ Implemented (December 30, 2025)
**API Version:** 0.6.5
**Tool Integration Version:** 0.3.11

- [x] Fuzzer scans complete successfully ✅ (echidna scan verified 2025-12-29, ~32s)
- [x] Fuzzer scans populate `fuzzing_results` table ✅ (verified 2025-12-30)
- [x] FuzzingResultsPanel displays test results ✅ (verified 2025-12-30)
- [x] Panel shows test pass/fail status ✅ (verified 2025-12-30)
- [x] Panel shows coverage percentage ✅ (verified 2025-12-30)
- [x] Failed tests show counterexamples/failure traces ✅ (verified 2025-12-30)

#### 12.6.1 Fuzzing Results API
- [x] `GET /api/v1/scans/{id}/result-types` returns `fuzzing` for fuzzer scans ✅
- [x] `GET /api/v1/scans/{id}/fuzzing-results` returns fuzzing test data ✅
- [x] Filter by status (passed/failed/error) works correctly ✅
- [x] Pagination works on fuzzing results ✅

#### 12.6.2 Fuzzing Results Panel UI
- [x] Panel appears only when result-types includes "fuzzing" ✅
- [x] Summary stats show passed/failed/error counts ✅
- [x] Average coverage percentage displayed ✅
- [x] Status filter dropdown always visible (even with 0 results) ✅
- [x] Filter state persists when changing selections ✅
- [x] Empty state shows appropriate message for filter vs no tests ✅

#### 12.6.3 Scanner-Specific Behavior

**Echidna:**
- [x] Callback posts to tool-integration correctly ✅
- [x] EchidnaParser extracts test results and vulnerabilities ✅
- [x] Creates `echidna_scan_summary` fuzzing result record ✅
- [x] Property violations appear as vulnerabilities ✅

**Medusa:**
- [x] Handles exit code 6 (no tests found) gracefully ✅
- [x] Callback posts even when no property tests exist ✅
- [x] MedusaParser handles wrapper format (`tool: "medusa"`) ✅
- [x] Creates `medusa_scan_summary` fuzzing result record ✅
- [x] Findings from assertion/property failures captured ✅
- [x] Coverage percentage from metadata displayed ✅

**Note:** Fuzzing results table population now works for all contracts. For contracts without property tests (no `echidna_*` or `property_*` functions), a summary record is created showing "passed" with 0 coverage.

---

## Test Notes - Fuzzer Filtering

```
[Date] | [Test] | [Result] | [Notes]
2025-12-29 | API is_project=false | PASS | Returns 8 scanners, no fuzzers
2025-12-29 | API is_project=true | PASS | Returns 15 scanners including fuzzers
2025-12-29 | Preset filtering | PASS | Fuzzers removed from single-file presets
2025-12-29 | Scanner metadata | PASS | requires_project field present on all scanners
2025-12-29 | Single-file scan | PASS | Slither scan on VulnerableClassicReentrancy, 28 vulns
2025-12-29 | Foundry upload | PASS | Project detected, is_project=true, framework=foundry
2025-12-29 | Echidna scan | PASS | Completed in ~32s on Foundry project
```

### Test Artifacts

**Contracts tested:**
- Single-file: `VulnerableClassicReentrancy` (Solidity, id: 09266055-275d-4c66-893c-e34874012d9e)
- Project: `foundry-test-project` (Foundry, id: 494b0c1f-0af8-4580-9316-71ddfe57f7e8)

**Scans executed:**
- Slither scan: `5e6ad92b-bac1-461b-9348-cbc1a9565f17` (single-file, completed)
- Echidna scan: `c16a0d64-a2ad-463f-8666-680d22b61b33` (project, completed)

**API versions tested:**
- API Service: 0.6.5
- Dashboard: 0.6.1
- Tool Integration: 0.3.11

---

## 13. Fuzzing Results End-to-End Testing (December 30, 2025)

### 13.1 Pre-Test Setup

1. Ensure all fuzzer scanner images are built:
   ```bash
   eval $(minikube docker-env)
   docker images | grep -E "^scanner-(echidna|medusa|halmos|moccasin)"
   ```

2. Verify API and Tool Integration versions:
   ```bash
   kubectl get deployment api-service -n api-service-local -o jsonpath='{.spec.template.spec.containers[0].image}'
   kubectl get deployment tool-integration -n tool-integration-local -o jsonpath='{.spec.template.spec.containers[0].image}'
   ```

### 13.2 Echidna Scan Test

**Test Steps:**
1. Upload a Foundry project with property tests (Counter.sol with `echidna_count_always_positive`)
2. Navigate to contract detail page
3. Click "Scan" and select "echidna" scanner
4. Wait for scan to complete (~30-60 seconds)
5. Navigate to scan results page

**Expected Results:**
- [ ] Scan status shows "completed"
- [ ] "Fuzzing Test Results" panel appears
- [ ] Summary shows passed/failed counts
- [ ] Test name `echidna_scan_summary` visible
- [ ] Coverage percentage displayed (may be 0% for basic contracts)

### 13.3 Medusa Scan Test

**Test Steps:**
1. Upload a Foundry project (even without property tests)
2. Navigate to contract detail page
3. Click "Scan" and select "medusa" scanner
4. Wait for scan to complete (~10-30 seconds)
5. Navigate to scan results page

**Expected Results:**
- [ ] Scan status shows "completed"
- [ ] "Fuzzing Test Results" panel appears
- [ ] Test name `medusa_scan_summary` visible
- [ ] Status shows "passed" (for contracts without property tests)
- [ ] Metadata shows fuzz configuration (workers, test limit, timeout)

### 13.4 Filter Functionality Test

**Test Steps:**
1. Navigate to a completed fuzzer scan
2. In "Fuzzing Test Results" panel, click status filter dropdown
3. Select "Failed"
4. Verify results update
5. Select "Passed"
6. Verify results update
7. Select "All Statuses"
8. Verify all results shown

**Expected Results:**
- [ ] Filter dropdown always visible
- [ ] Changing filter updates results
- [ ] "No [status] tests" message when filter has no matches
- [ ] Can return to "All Statuses" after filtering

### 13.5 Database Verification

```sql
-- Check fuzzing results table
SELECT scan_id, scanner_id, test_name, status, executions, coverage_percentage
FROM fuzzing_results
ORDER BY created_at DESC
LIMIT 10;

-- Verify result-types endpoint logic
SELECT id, scanners_used
FROM scans
WHERE 'medusa' = ANY(scanners_used) OR 'echidna' = ANY(scanners_used)
ORDER BY created_at DESC
LIMIT 5;
```

### 13.6 Bug Fixes Verified (December 30, 2025)

| Issue | Fix | Verified |
|-------|-----|----------|
| result-types endpoint hardcoded to slither | Use `scan.scanners_used` field | ✅ |
| edge_cases_found NULL validation error | Add model_validate override | ✅ |
| Filter dropdown disappearing | Move filter outside `total === 0` conditional | ✅ |
| Medusa exit code 6 killing script | Changed to `set -uo pipefail`, handle exit codes | ✅ |
| MedusaParser format mismatch | Support wrapper format with `tool: "medusa"` | ✅ |
| Empty fuzzing results for medusa | Always create summary record | ✅ |
