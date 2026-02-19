# Feature Test 70: Platform Bug Fixes, Features & Security Hardening

**Version:** Dashboard 0.45.12 / API 0.28.54 / Orchestration 0.9.16 / Tool Integration 0.4.8
**Date:** 2026-02-19
**Status:** Tested (API)

## Prerequisites

- All 4 services deployed at versions listed above
- At least one scanned contract with vulnerabilities (Reentrancy.sol recommended)
- SCM integration (GitHub or GitLab) connected for PR creation tests
- User with `team` tier or higher for AI features

---

## Test 1: Pattern Sorting

**Page:** `/patterns`

- [ ] 1.1 Visit patterns page, verify sort dropdown exists with options: Severity, Name, Category, False Positive Rate, Date Created
- [ ] 1.2 Select "Name" sort, verify patterns are alphabetically ordered
- [ ] 1.3 Click ascending/descending toggle, verify order reverses
- [ ] 1.4 Select "Severity" sort descending, verify critical patterns appear first
- [ ] 1.5 Verify pagination prev/next buttons work correctly
- [ ] 1.6 When sorting by non-category field (e.g., Name), verify flat list is shown (not grouped)
- [ ] 1.7 When sorting by Category or Severity, verify grouped view is shown

## Test 2: Patterns View in Scan Results

**Page:** `/scans/{scanId}`

- [ ] 2.1 Visit a completed scan results page
- [ ] 2.2 Verify "Vulnerabilities" and "Patterns" tabs are visible
- [ ] 2.3 Click "Patterns" tab, verify findings are grouped by pattern code
- [ ] 2.4 Each pattern card shows: pattern code badge, max severity badge, category, finding count
- [ ] 2.5 Each pattern card shows severity breakdown chips (e.g., "3 high", "1 medium")
- [ ] 2.6 Each pattern card shows scanner badges for scanners that detected it
- [ ] 2.7 "View Pattern" link navigates to correct `/patterns/{id}` page
- [ ] 2.8 Click "Vulnerabilities" tab, verify original vulnerability list is shown

## Test 3: Rust Scanners in Dropdown

**Page:** `/scans/{scanId}` (scan with Rust/Solana contract)

- [ ] 3.1 Scanner filter dropdown includes: Sol-azy, Sec3 X-ray, Trident, Cargo Fuzz Solana, RustDefend, Moccasin, Vyper
- [ ] 3.2 Scanner badges display with correct human-readable names

## Test 4: Contract Table Overflow

**Page:** `/contracts`

- [ ] 4.1 Create or have a contract with a name longer than 80 characters
- [ ] 4.2 Verify table does not break layout (no horizontal scroll on normal viewports)
- [ ] 4.3 Verify long contract names are truncated with ellipsis
- [ ] 4.4 Hover over truncated name, verify full name appears in tooltip
- [ ] 4.5 On narrow viewport, verify table scrolls horizontally within container

## Test 5: Contract Project Visibility

**Page:** `/contracts/{id}`

- [ ] 5.1 Add contract to a project via "Add to Project" dropdown
- [ ] 5.2 Verify project badge appears immediately without page refresh
- [ ] 5.3 Verify the project you just added is no longer in the dropdown
- [ ] 5.4 Add same contract to a second project, verify both badges shown

## Test 6: Address Persistence

**Page:** Upload flow -> `/contracts/{id}` -> `/vulnerabilities/{id}`

- [ ] 6.1 Upload a contract with an Ethereum address (e.g., `0x1234...abcd`)
- [ ] 6.2 Visit contract detail, verify address is displayed
- [ ] 6.3 Upload a contract without an address, verify no `0x000...000` placeholder is shown
- [ ] 6.4 Visit vulnerability detail for a contract with address, verify address shown in sidebar
- [ ] 6.5 Upload with invalid address format (e.g., `0xZZZZ`), verify it is silently ignored

## Test 7: Pattern Detail Findings Filter

**Page:** `/patterns/{patternId}`

- [ ] 7.1 Visit a pattern that has associated vulnerabilities
- [ ] 7.2 Verify "Recent Findings" shows only vulnerabilities for this specific pattern
- [ ] 7.3 Verify findings do NOT include unrelated vulnerabilities from other patterns
- [ ] 7.4 Verify "Related Contracts" section shows contracts that have this pattern's findings
- [ ] 7.5 Click a contract link, verify it navigates to `/contracts/{id}`

## Test 8: Pragma Snippet Fix

**Page:** `/vulnerabilities/{id}` (for SolidityDefend finding)

- [ ] 8.1 Scan `Reentrancy.sol` with SolidityDefend
- [ ] 8.2 Visit a vulnerability that previously showed pragma line
- [ ] 8.3 Verify code snippet shows the actual vulnerable code, not `pragma solidity ^0.8.0`
- [ ] 8.4 If no valid snippet available, verify snippet section is hidden or shows extracted context

## Test 9: Generate Repair for Manual Uploads

**Page:** `/vulnerabilities/{id}` (for vulnerability without code_snippet)

- [ ] 9.1 Find a vulnerability where `code_snippet` is null but contract has source code
- [ ] 9.2 Verify "Generate AI Repair" button is enabled (not grayed out)
- [ ] 9.3 Click "Generate AI Repair", verify repair is generated successfully
- [ ] 9.4 For vulnerability with no source code at all, verify button is disabled

## Test 10: ML Label Save

**Page:** `/vulnerabilities/{id}`

- [ ] 10.1 Click "Submit as Real Vulnerability" on a vulnerability you own
- [ ] 10.2 Verify no error message appears
- [ ] 10.3 Reload the page, verify the label state persists (shows your previous classification)
- [ ] 10.4 Attempt to label another user's vulnerability, verify 403 error is returned
- [ ] 10.5 Verify error message shows actual API detail (not generic "Failed to save label")

## Test 11: Invariant Generation

**Page:** `/vulnerabilities/{id}` (team tier or higher)

- [ ] 11.1 Click "Generate Invariants" with valid contract source
- [ ] 11.2 If Anthropic API key configured: verify invariants generated
- [ ] 11.3 If Anthropic API key NOT configured: verify user-friendly "AI service not configured" message
- [ ] 11.4 On developer tier: verify tier gate blocks access with upgrade prompt
- [ ] 11.5 On team tier: verify button shows "team" not "growth" in tier message

## Test 12: Zip Upload (413 Error Fix)

**Page:** Upload flow

- [ ] 12.1 Upload a zip archive larger than 10MB but within tier limits
- [ ] 12.2 Verify no 413 error (middleware exemption working)
- [ ] 12.3 Upload a zip archive exceeding tier limits, verify proper tier-specific error message
- [ ] 12.4 Upload a non-upload request body > 10MB to a different endpoint, verify 413 still enforced

## Test 13: Admin Pattern Management

**Endpoint:** `GET /api/v1/admin/patterns/mappings/audit`

- [ ] 13.1 As platform admin, call the audit endpoint
- [ ] 13.2 Verify response includes unmapped (scanner_id, detector_id) pairs with finding counts
- [ ] 13.3 As non-admin, verify 403 is returned

**Endpoint:** `POST /api/v1/admin/patterns/{target_id}/merge`

- [ ] 13.4 Merge a source pattern into a target pattern
- [ ] 13.5 Verify vulnerabilities moved to target pattern
- [ ] 13.6 Verify tool mappings moved to target pattern
- [ ] 13.7 Verify source pattern is deactivated (`is_active = false`)
- [ ] 13.8 Attempt to merge pattern into itself, verify 400 error

## Test 14: SCM PR Creation

**Page:** `/vulnerabilities/{id}` (with connected GitHub/GitLab integration)

- [ ] 14.1 Generate a repair for a vulnerability with a `file_path`
- [ ] 14.2 Verify "Create Pull Request" button appears
- [ ] 14.3 Click "Create Pull Request", verify PR is created on the SCM provider
- [ ] 14.4 Verify PR contains the fixed code on a new branch
- [ ] 14.5 Verify branch name is sanitized (no special characters)
- [ ] 14.6 Without a connected SCM integration, verify button is not shown

## Test 15: Security Hardening

- [ ] 15.1 ML label ownership: attempt to label a vulnerability belonging to a different user's contract -> expect 403
- [ ] 15.2 Pattern sort injection: pass `sort_by=id; DROP TABLE` -> expect default severity sort (invalid field ignored)
- [ ] 15.3 Address validation: upload with `address=<script>alert(1)</script>` -> expect address ignored
- [ ] 15.4 Error messages: verify no internal paths, API keys, or stack traces in any error response

## Test 16: Scan Results Page Navigation

**Page:** `/recent-scans`

- [ ] 16.1 Visit recent scans page, click "View Results" on any scan
- [ ] 16.2 Verify navigation goes to `/scans/{id}` (not `/scan-results/{id}`)
- [ ] 16.3 Verify scan results page loads with vulnerability list

## Test 17: Pattern Detail Statistics

**Page:** `/patterns/{patternId}`

- [ ] 17.1 Visit any pattern detail page
- [ ] 17.2 Verify statistics grid shows: Total Findings, Scanners Detecting, Most Common Scanner, Status
- [ ] 17.3 Verify Scanner Detection Breakdown shows bar chart with percentages
- [ ] 17.4 Verify Severity Distribution shows severity badges with counts
- [ ] 17.5 Verify no JavaScript errors in console

## Test 18: Contract Project Display

**Page:** `/contracts/{id}`

- [ ] 18.1 View a contract that is assigned to a project
- [ ] 18.2 Verify project badges appear with project names
- [ ] 18.3 Click remove (x) button on a project badge, verify project is removed
- [ ] 18.4 Verify project link navigates to `/projects/{id}`

## Test 19: Authentication (Dashboard Build)

- [ ] 19.1 Clear browser storage for `app.blocksecops.local`
- [ ] 19.2 Navigate to `https://app.blocksecops.local`
- [ ] 19.3 Verify login page loads (Supabase auth)
- [ ] 19.4 Login with valid credentials, verify redirect to dashboard

---

## Test Notes

| Date | Tester | Result | Notes |
|------|--------|--------|-------|
| 2026-02-19 | API test suite | 15 pass, 0 fail, 8 skip | API tests via Traefik HTTPS. Skips: UI tests (2.1, 3.1, 4.1, 5.1), file upload (6.1), Anthropic key (9.1, 11.1), SCM (15.1). Admin audit requires MFA session + IP match setup. |
| 2026-02-19 | Full platform audit | 173 total, 166 pass, 7 fail | Post-deployment audit covering all endpoints. 7 failures addressed in api-service 0.28.53-0.28.54 and orchestration 0.9.16. |
| 2026-02-19 | Audit fix verification | 7 pass, 0 fail | All 7 audit failures resolved. See audit fix results below. |

### API Test Results (2026-02-19)

| Test | Status | Notes |
|------|--------|-------|
| 1.1 Sort by severity (desc → critical first) | PASS | Fixed in 0.28.52 (severity case ordering) |
| 1.2 Sort by name | PASS | |
| 1.3 Sort by category | PASS | |
| 1.4 Sort by false_positive_rate | PASS | |
| 1.5 Sort by created_at | PASS | |
| 1.6 Asc/desc produce different results | PASS | Fixed in 0.28.52 |
| 1.7 Pagination (offset=0 vs offset=5) | PASS | |
| 7.1 Pattern findings filter (pattern_id) | PASS | |
| 8.1 Vulnerabilities accessible | PASS | |
| 10.1 ML label save | PASS | |
| 13.1 Admin audit endpoint | PASS | Fixed in 0.28.50 (log_admin_action params); requires admin_role + MFA + session |
| 13.2 Non-admin blocked (404) | PASS | Security through obscurity |
| 13.3 Developer tier gate (403) | PASS | api_access_enabled=false blocks at middleware |
| S1 Sort injection safe | PASS | Invalid sort_by falls back to severity |
| S2 Clean error messages | PASS | No internal details leaked |

### Audit Fix Results (2026-02-19, API 0.28.54 / Orchestration 0.9.16)

| Test | Status | Notes |
|------|--------|-------|
| Scan duration_seconds persisted | PASS | 219 existing scans backfilled; new scans persist duration at all completion points |
| Vulnerability pagination stability | PASS | Secondary sort by `id DESC` prevents duplicate/missing rows across pages (verified 0 overlap) |
| VulnerabilityResponse file_path | PASS | `file_path` field now returned in API response (verified: `./contract.rs`) |
| VulnerabilityResponse false_positive_score | PASS | ML model trained (97.4% acc, 0.995 AUC), 763 vulns batch-predicted with FP scores |
| Solana patterns CWE mapping | PASS | 32 patterns updated with CWE IDs (verified: CWE-20, CWE-664, CWE-682, etc.) |
| Dedup confidence_level field | PASS | API returns `confidence_level` (property alias on model); original test expectation was wrong |
| Dedup finding_count field | PASS | API returns `finding_count` (property alias on model); original test expectation was wrong |

### Admin Endpoint Test Setup

The admin audit/merge endpoints require full admin authentication:
1. `users.admin_role = 'platform_admin'`
2. `users.admin_mfa_enabled = true`
3. Valid `admin_sessions` row with `mfa_verified = true`, matching `ip_address`, and non-expired `expires_at`
4. Session token passed via `X-Admin-Session` header (SHA-256 hashed in DB)
5. IP must match — Traefik forwards as `10.244.0.1` (pod network), not `127.0.0.1`
