# Scanning Tests

**Priority**: P0 - Critical
**Last Tested**: December 22, 2025
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
