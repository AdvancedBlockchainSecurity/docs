# BlockSecOps Feature Tests

Manual testing checklists for all user-facing features.

## Status Legend

| Status | Meaning |
|--------|---------|
| [ ] | Not tested |
| [x] | Passed |
| [!] | Failed |

---

## Test Files

| File | Features |
|------|----------|
| [01-authentication.md](./01-authentication.md) | Login, logout, registration, sessions |
| [02-quota-system.md](./02-quota-system.md) | Tier limits, scan quotas, file limits |
| [03-file-upload.md](./03-file-upload.md) | Single file and archive uploads |
| [04-framework-detection.md](./04-framework-detection.md) | Foundry, Hardhat, OpenZeppelin support |
| [05-projects.md](./05-projects.md) | Projects CRUD and dashboard |
| [06-scanning.md](./06-scanning.md) | Scan triggers, results, scanner selection |
| [07-pricing-page.md](./07-pricing-page.md) | Pricing display and upgrade flows |
| [08-api-responses.md](./08-api-responses.md) | API response validation |
| [09-error-handling.md](./09-error-handling.md) | Error messages and edge cases |
| [10-tier-upgrades.md](./10-tier-upgrades.md) | Free to Pro/Enterprise upgrades |
| [11-wallet-authentication.md](./11-wallet-authentication.md) | MetaMask/WalletConnect auth |
| [12-enhanced-contract-details.md](./12-enhanced-contract-details.md) | Contract metadata, security score |
| [13-vyper-rust-scanners.md](./13-vyper-rust-scanners.md) | Vyper & Solana/Rust scanners |
| [14-enterprise-features.md](./14-enterprise-features.md) | Webhooks, RBAC, SSO, API Keys |
| [15-x402-pay-per-scan.md](./15-x402-pay-per-scan.md) | USDC payments, credits |
| [16-user-activity-logging.md](./16-user-activity-logging.md) | Activity log, filtering, tracking |
| [17-scan-comparison.md](./17-scan-comparison.md) | Scan diff, export reports |
| [18-favorites-annotations.md](./18-favorites-annotations.md) | Favorites, vulnerability annotations |
| [19-scanner-effectiveness.md](./19-scanner-effectiveness.md) | Scanner effectiveness analytics |
| [20-batch-scan.md](./20-batch-scan.md) | Batch scan operations |
| [21-phase-3-dashboard-analytics.md](./21-phase-3-dashboard-analytics.md) | Phase 3 dashboard analytics |
| [22-scanner-validation.md](./22-scanner-validation.md) | Per-scanner validation tests (all 17 scanners) |
| [23-vulnerability-categorization.md](./23-vulnerability-categorization.md) | Category validation, pattern mappings, scan stats |
| [24-cross-scanner-deduplication.md](./24-cross-scanner-deduplication.md) | Deduplication API, cross-scanner matching, group management |
| [25-dark-mode-global-search.md](./25-dark-mode-global-search.md) | Dark mode toggle, command palette (Cmd+K), source code search |
| [26-team-collaboration.md](./26-team-collaboration.md) | Teams, project access, assignments, comments (Phase 4.5) |
| [27-ai-ml-features.md](./27-ai-ml-features.md) | False positive detection, risk scoring, prioritization (Phase 5 - Implemented) |
| [28-webapp-security.md](./28-webapp-security.md) | Security headers, CORS, request limits, error handling (Phase 7A) |
| [29-application-security.md](./29-application-security.md) | OWASP testing, SQL injection, XSS, auth security, input validation |
| [30-dashboard-production.md](./30-dashboard-production.md) | Production build, build args, static serving, Supabase integration |
| [31-risk-scoring.md](./31-risk-scoring.md) | Unbounded risk scoring, risk levels, per-project breakdown |
| [32-contract-name-duplication.md](./32-contract-name-duplication.md) | Duplicate contract name handling, rename/overwrite modal |

---

## Phase 7A Security Hardening (Implemented)

Security hardening features for production deployment:

| Feature | Status | Tests |
|---------|--------|-------|
| Security Headers | Implemented | X-Frame-Options, CSP, HSTS |
| CORS Restriction | Implemented | Explicit methods/headers |
| Request Size Limit | Implemented | 10MB max, 413 response |
| Error Handling | Implemented | Generic errors in production |
| Security Logging | Implemented | Auth events, rate limits |
| SQL Logging Control | Implemented | Disabled in production |

---

## Phase 5 AI/ML Features (Implemented)

Phase 5 CPU-only ML features are now implemented (~$1/month operating cost):

| Feature | Status | Tests |
|---------|--------|-------|
| False Positive Detection | Implemented (needs training data) | FP probability endpoint, training API |
| Risk Scoring | **Redesigned (v0.7.0)** | Unbounded scoring, CRITICAL/HIGH/MEDIUM/LOW levels |
| Confidence Scoring | Implemented | Multi-signal weighted combination |
| Semantic Deduplication | Implemented | Sentence Transformers embeddings |
| Smart Prioritization | Implemented | Priority ranking, composite scoring |

### Risk Scoring Redesign (December 30, 2025)

The risk scoring system was redesigned to be unbounded (higher = riskier):

- **Weights**: Critical=25, High=15, Medium=5, Low=1, Info=0
- **Thresholds** (per-contract avg): CRITICAL>=50, HIGH>=25, MEDIUM>=10, LOW<10
- **No cap**: Previously capped at 100, now accurately reflects total risk
- **New endpoint**: GET /api/v1/statistics/risk for per-project breakdown

---

## Test Notes

```
[Date] | [Tester] | [File] | [Result]
2025-12-31 | Claude Code | 32-contract-name-duplication.md | IMPLEMENTED - 409 conflict detection, DuplicateContractModal (v0.8.0 API, v0.22.0 Dashboard)
2025-12-30 | Claude Code | 31-risk-scoring.md | PASS - Color badge display implemented (v0.21.0), replaces numeric 60.8k with "Critical Risk" badge
2025-12-30 | Claude Code | 30-dashboard-production.md | PASS - Production build with build args verified
2025-12-30 | Claude Code | 06-scanning.md (Sections 12.6, 13) | PASS - Fuzzer results display E2E verified
2025-12-28 | Claude Code | 28-webapp-security.md | PASS - All security headers, CORS, request limits verified
2025-12-27 | Claude Code | 27-ai-ml-features.md | PARTIAL - ML endpoints implemented, FP classifier needs training data
2025-12-27 | Claude Code | 26-team-collaboration.md | PASS - Teams API, project access, assignments, comments verified
2025-12-26 | Claude Code | 25-dark-mode-global-search.md | PASS - Dark mode persists, Command Palette works, Source code search verified
2025-12-25 | Claude Code | 24-cross-scanner-deduplication.md | PASS - 137 groups, 421 findings deduplicated, API verified
2025-12-23 | Claude Code | 23-vulnerability-categorization.md | PASS - All 832 vulns categorized, scan stats fixed
2025-12-22 | Manual | 13-vyper-rust-scanners.md | PASS - Phase 3.5 E2E integration complete
2025-12-22 | Manual | 06-scanning.md | PASS - Language-based scanner selection working
2025-12-21 | Claude Code (Automated) | 06-scanning.md (Section 11) | PASS - Scanner Pattern Coverage validated
```
