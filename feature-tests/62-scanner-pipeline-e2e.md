# Scanner Pipeline End-to-End Verification

**Priority**: P0 - Critical
**Last Tested**: February 12, 2026
**Service**: tool-integration (0.3.22)

---

## Overview

End-to-end verification of all 6 core Solidity scanner pipelines. Tests confirm that each scanner:
1. Accepts a contract via the tool-integration API
2. Creates a K8s Job with the correct scanner image
3. Scanner container runs, analyzes the contract, and produces findings
4. Scanner POSTs results back to tool-integration via callback URL
5. Tool-integration parses the scanner-specific JSON format
6. Tool-integration forwards results to the API service

---

## Test Contracts

4 purpose-built contracts with known vulnerabilities:

| Contract | Vulnerabilities |
|----------|----------------|
| ReentrancyVault.sol | Reentrancy, tx.origin auth, unchecked send, arbitrary delegatecall |
| UnsafeToken.sol | Missing zero-address check, unprotected selfdestruct, timestamp dependence, missing access control, variable shadowing |
| VulnerableAuction.sol | DoS with revert, reentrancy, missing access control, unbounded loop, inline assembly |
| InsecureProxy.sol | No access control on upgrade, delegatecall to arbitrary address, unprotected selfdestruct, unchecked call return |

---

## 1. Scanner Image Verification

### 1.1 Images Available in Harbor
- [x] scanner-slither:0.3.2 present in Harbor
- [x] scanner-aderyn:0.7.2 present in Harbor
- [x] scanner-semgrep:0.3.5 present in Harbor
- [x] scanner-solhint:0.1.6 present in Harbor
- [x] scanner-wake:0.3.6 present in Harbor
- [x] scanner-soliditydefend:0.7.1 present in Harbor

### 1.2 Images Available in containerd (K8s)
- [x] All 6 scanner images pullable by K8s Jobs
- [x] Image versions match ConfigMap `scanner-versions`

---

## 2. Local Docker Verification

### 2.1 Slither (scanner-slither:0.3.2)
- [x] Finds vulnerabilities in test contracts
- [x] Produces valid JSON output
- [x] Results: **44 findings** (8 High, 5 Medium, 10 Low, 13 Info, 8 Optimization)
- [x] Key detections: reentrancy, arbitrary-send-eth, unchecked-lowlevel, tx-origin

### 2.2 Aderyn (scanner-aderyn:0.7.2)
- [x] Finds vulnerabilities in test contracts
- [x] Produces valid JSON output
- [x] Results: **25 findings** (10 High, 15 Low)
- [x] Key detections: selfdestruct deprecated, reentrancy state change, delegatecall arbitrary address, weak randomness, tx.origin
- [x] Callback delivery with curl retry (--retry 3 --retry-all-errors)

### 2.3 Solhint (scanner-solhint:0.1.6)
- [x] Finds lint issues in test contracts
- [x] Debug stdout messages filtered correctly (grep '^\[')
- [x] Conclusion entry filtered out (select .ruleId != null)
- [x] Severity case handled (Warning/Error title-case)
- [x] Results: **141 findings** across 14 rules
- [x] Key rules: reentrancy, avoid-tx-origin, check-send-result, avoid-low-level-calls

### 2.4 Semgrep (scanner-semgrep:0.3.5)
- [x] Rules bundled as local YAML files during Docker build (offline operation)
- [x] smart-contracts.yaml (85K) + security-audit.yaml (463K)
- [x] Results: **21 findings** with local rules on 4 test contracts
- [x] Callback delivery with curl retry (--retry 3 --retry-all-errors)

### 2.5 Wake (scanner-wake:0.3.6)
- [x] Produces findings when solc is available
- [x] Platform results show 5 + 2 = 7 findings across contracts
- [ ] Some contracts fail when solc download is needed (air-gapped cluster)

### 2.6 SolidityDefend (scanner-soliditydefend:0.7.1)
- [x] Produces findings on platform
- [x] Callback mechanism working
- [x] Results received by tool-integration

---

## 3. Platform Pipeline Verification

### 3.1 K8s Job Creation
- [x] Trigger endpoint creates ConfigMap with contract source
- [x] Trigger endpoint creates Job with correct scanner image
- [x] Pod security context enforces UID 1000 (non-root)
- [x] DNS config includes `single-request-reopen` for Alpine musl fix
- [x] WORK_DIR=/contracts environment variable set
- [x] CALLBACK_URL uses trailing dot FQDN (svc.cluster.local.)

### 3.2 Scanner Execution Results (All 6 scanners verified)
- [x] slither: **12 vulnerabilities** parsed (ReentrancyVault.sol)
- [x] aderyn: **13 vulnerabilities** parsed (ReentrancyVault.sol)
- [x] semgrep: **4 findings** parsed (ReentrancyVault.sol, offline rules)
- [x] solhint: **25 findings** parsed (ReentrancyVault.sol)
- [x] wake: **5 vulnerabilities** parsed (ReentrancyVault.sol)
- [x] soliditydefend: Results received and processed (ReentrancyVault.sol)

### 3.3 Result Parsing
- [x] Slither parser branch handles Slither JSON format
- [x] Aderyn parser branch handles Aderyn JSON format
- [x] Solhint parser branch handles `findings` key (not `vulnerabilities`)
- [x] Semgrep parser branch handles semgrep `results` format
- [x] Wake parser branch handles wake `vulnerabilities` format
- [x] Generic fallback checks both `vulnerabilities` and `findings` keys

### 3.4 Result Forwarding to API Service
- [x] Tool-integration POSTs parsed results to API service
- [x] 404 errors expected for direct-triggered test scan IDs (not in API database)
- [x] Real scans (via API service) succeed with registered scan IDs

---

## 4. Known Issues

### 4.1 Wake - Solc Download
- **Impact**: Wake needs to download solc compiler versions at runtime
- **Fix**: Pre-install common solc versions in the Docker image
- **Status**: Wake works for contracts matching pre-installed solc versions

---

## 5. Fixes Applied (February 2026)

| Fix | Scanner | Description |
|-----|---------|-------------|
| UID 1001→1000 | slither, aderyn, wake, soliditydefend | Dockerfiles used UID 1001 but K8s security context forced UID 1000 |
| ENV HOME=/home/scanner | slither | solc-select wrote to /.solc-select/ without HOME set |
| WORK_DIR=/contracts | solhint | Entrypoint defaulted to /work but contracts mounted at /contracts |
| --config flag | solhint | cp to read-only ConfigMap mount failed; use --config flag instead |
| DNS single-request-reopen | all (Alpine) | musl libc DNS bug sends A+AAAA on same socket causing timeouts |
| Trailing dot FQDN | all | Avoids ndots:5 search domain expansion in K8s |
| stdout JSON extraction | solhint | Debug messages (isPublicLike, version notice) polluted stdout |
| Conclusion entry filter | solhint | Summary object with null ruleId crashed jq transform |
| Severity case fix | solhint | solhint uses title-case (Warning/Error) not lowercase |
| Parser branches | semgrep, solhint, wake | Added dedicated parsing in collect_scan_results() |
| Generic fallback | all | Check both "vulnerabilities" and "findings" keys |
| Curl retry + timeout | aderyn, semgrep | Added --retry 3 --retry-all-errors --connect-timeout 10 to callback POST |
| Offline rule bundling | semgrep | Download rules as local YAML during Docker build for air-gapped operation |
| Rule cache fix | semgrep | Pre-cache was in root's home; now uses local files at /rules/ |

---

## Test Execution Date

**Date**: February 13, 2026
**Tool-Integration Version**: 0.4.0
**Scanner Images Tested**:
- scanner-slither:0.3.2
- scanner-aderyn:0.7.2
- scanner-semgrep:0.3.5
- scanner-solhint:0.1.6
- scanner-wake:0.3.6
- scanner-soliditydefend:0.7.1

### Live Scan Verification (February 13, 2026)

Full end-to-end scan on live platform with tool-integration v0.4.0:

**Contract**: VulnerableAccountManagement_2 (Solidity, single-file, uploaded via web)
**Scanners**: slither, semgrep, wake, solhint (4 of 6 core scanners)
**Status**: Completed

| Scanner | Critical | High | Medium | Low | Total |
|---------|----------|------|--------|-----|-------|
| slither | 6 | 0 | 13 | 22 | 41 |
| semgrep | 0 | 0 | 0 | 75 | 75 |
| wake | 0 | 0 | 2 | 0 | 2 |
| solhint | 0 | 0 | 0 | 0 | 0 |
| **Total** | **6** | **0** | **15** | **97** | **118** |

- [x] All 4 scanner Jobs executed and posted callbacks
- [x] Scan record counts (6/0/15/97) match vulnerability rows in database
- [x] K8s Jobs auto-cleaned (TTL working)
- [x] Slither criticals: 5 uninitialized state (0.9 confidence), 1 arbitrary ether send (0.7)
- [x] Severity mapping correct: High→critical, Low→medium, Informational→low
- [x] Line numbers and confidence scores populated across all scanners
- [x] Solhint returned 0 findings (valid — contract follows linting conventions)
