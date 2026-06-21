# Apogee Feature Tests

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
| [22-scanner-validation.md](./22-scanner-validation.md) | Per-scanner validation tests (all 18 scanners) |
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
| [33-pricing-page-usage.md](./33-pricing-page-usage.md) | Pricing page subscription alignment, current plan display |
| [34-notification-channels.md](./34-notification-channels.md) | Slack, Teams, Discord webhook notifications (CI/CD Integrations) |
| [35-cli-tool.md](./35-cli-tool.md) | CLI tool, pre-commit hooks, output formats (CI/CD Integrations) |
| [36-cicd-integration.md](./36-cicd-integration.md) | GitHub Actions, GitLab CI, Jenkins, Azure Pipelines integration |
| [37-stripe-billing.md](./37-stripe-billing.md) | Stripe subscriptions, invoices, receipts (Phase 8a) |
| [38-cursor-pagination.md](./38-cursor-pagination.md) | Cursor-based pagination, keyset queries |
| [39-economic-security-analysis.md](./39-economic-security-analysis.md) | Economic security panel, flash loan/MEV/DeFi detection, AI explanations (Phase 5.5a) |
| [40-quality-gates.md](./40-quality-gates.md) | CI/CD Quality Gates, blocking rules, thresholds, badges, evaluation history (Phase 5.5c) |
| [41-vulnerability-filtering.md](./41-vulnerability-filtering.md) | Vulnerability filtering, scanner dropdown, pattern input, copy button (Bug fixes Jan 2026) |
| [42-ide-integration.md](./42-ide-integration.md) | IDE integrations: VS Code, JetBrains, Neovim, CLI local scanning (Phase 6) |
| [43-dashboard-enhancement-jan2026.md](./43-dashboard-enhancement-jan2026.md) | Dashboard enhancements: layout, theme toggle, API key limits, status dropdown, new pages (Jan 2026) |
| [44-platform-integrations.md](./44-platform-integrations.md) | Platform integrations: GitHub, GitLab, Bitbucket, Jira (OAuth, repositories, issue sync) |
| [45-integrations-hub.md](./45-integrations-hub.md) | Integrations hub UI page |
| [46-platform-admin-panel.md](./46-platform-admin-panel.md) | Platform admin panel: MFA, user management, emergency actions (Phase 4.6) |
| [47-api-keys-security.md](./47-api-keys-security.md) | API key security, tier limits, validation |
| [48-ml-data-strategy.md](./48-ml-data-strategy.md) | ML Data Strategy: consent tracking, data provenance, GDPR compliance |
| [49-intelligence-cve-enrichment.md](./49-intelligence-cve-enrichment.md) | Intelligence CVE Enrichment: NVD/MITRE data, exploit-db correlation |
| [50-ai-invariant-generation.md](./50-ai-invariant-generation.md) | **NEW** - AI Invariant Generation: Foundry test generation, tier quotas, prompt injection prevention |
| [51-kubernetes-security.md](./51-kubernetes-security.md) | **NEW** - Kubernetes Security: revisionHistoryLimit, security contexts, NetworkPolicies, pod lifecycle |
| [52-dual-payment-options.md](./52-dual-payment-options.md) | **NEW** - Dual Payment Options: Stripe + x402 crypto, payment method selector, pricing page integration |
| [58-platform-v0.27-v0.40-v0.3-fixes.md](./58-platform-v0.27-v0.40-v0.3-fixes.md) | **NEW** - Platform-wide bug fixes - info severity removal, pending→queued, auto-apply filters, dark mode, admin portal enhancements |
| [59-admin-portal-v0.4.0.md](./59-admin-portal-v0.4.0.md) | **NEW** - Admin Portal v0.4.0: GCP Cost Estimator, Scanners page, Dependencies endpoint, defensive metrics |
| [60-collapsible-sidebar-quick-access.md](./60-collapsible-sidebar-quick-access.md) | **NEW** - Collapsible sidebar (w-64 ↔ w-16), quick access page pins (max 5), localStorage persistence (v0.41.4 Dashboard) |
| [61-ai-inline-results.md](./61-ai-inline-results.md) | **NEW** - AI inline results: Code Review & Code Repair display fully inline on vulnerability detail, auth fix for code-repair endpoints (v0.45.3 Dashboard, v0.28.32 API) |
| [66-scanner-audit-fixes.md](./66-scanner-audit-fixes.md) | **NEW** - Scanner audit fixes: solhint JSON extraction, vyper scanner_id attribution, stale scan recovery, canary UUID, code snippet fallback |
| [68-rate-limiting-security-audit.md](./68-rate-limiting-security-audit.md) | **UPDATED** - Rate limiting security audit: 37 endpoint files rate-limited (225+ endpoints), analytics dual-auth (v0.29.5 API) |
| [70-platform-bugfixes-features.md](./70-platform-bugfixes-features.md) | **NEW** - Platform bug fixes, features & security hardening: pattern sorting, patterns view, Rust scanners, contract overflow, project display, address persistence, pattern findings, code snippet validation, repair fallback, ML labeling, invariant errors, upload size, pattern merge/audit, SCM PR creation (v0.28.46 API, v0.45.9 Dashboard, v0.9.15 Orchestration, v0.4.8 Tool Integration) |
| [71-admin-scanners-kpi-dedup-fix.md](./71-admin-scanners-kpi-dedup-fix.md) | **NEW** - Admin scanners KPI (Total Scans, per-scanner counts), deduplication page min_scanner_count filter fix (v0.29.2 API, v0.7.3 Admin Portal, v0.46.1 Dashboard) |
| [77-integration-security-hardening.md](./77-integration-security-hardening.md) | **NEW** - Integration security hardening: webhook encryption, SSRF protection, error sanitization, input validation, URL validation, webhook domain checks (v0.29.22 API, v0.46.4 Dashboard) |
| [api-key-scope-enforcement.md](./api-key-scope-enforcement.md) | API key scope enforcement tests |
| [SCAN-TEST-2026-02-22.md](./SCAN-TEST-2026-02-22.md) | **NEW** - Cluster health audit scan tests: single/multi/full scanner, deduplication verification, auth 401 fix validation |
| [82-cors-domain-regression.md](./82-cors-domain-regression.md) | **NEW** - Automated CORS wildcard and legacy domain regression tests (64 tests across all repos) |
| [88-referral-system.md](./88-referral-system.md) | **NEW** - Referral system: code generation, sharing, applying, reward threshold, admin settings, dashboard UI, Stripe integration (v0.29.49 API, v0.46.13 Dashboard) |
| [89-gdpr-admin-data-requests.md](./89-gdpr-admin-data-requests.md) | **NEW** - GDPR admin data request processing: deletion (anonymization), export (0600 perms, 7-day expiry), ML-withdrawal (consent + provenance), path traversal protection, scan error_message fix (v0.29.55 API, v0.7.10 Admin Portal) |
| [90-tier-upsell-cta.md](./90-tier-upsell-cta.md) | **NEW** - Tier upsell & CTA audit: sidebar lock icons, dashboard feature discovery, scan quota pre-checks, AI tier gates, CI/CD tier split, cross-tier smoke tests (v0.46.28-v0.46.29 Dashboard) |

---

## Platform Integrations (January 2026)

Connect to external VCS and issue tracking platforms:

| Feature | Status | Tests |
|---------|--------|-------|
| GitHub Integration | Implemented | OAuth flow, repository import |
| GitLab Integration | Implemented | OAuth flow, repository import |
| Bitbucket Integration | Implemented | OAuth flow, repository import |
| Jira Integration | Implemented | OAuth flow, project mapping, issue sync |
| Repository Settings | Implemented | Auto-scan on push/PR, project linking |
| OAuth Security | Implemented | URL validation, token encryption |

**Tier Requirements:**
- GitHub/GitLab/Bitbucket: Starter+ tier
- Jira: Enterprise tier only

**Note:** Jenkins integration not implemented - use CLI tool with webhooks instead.

---

## Phase 5.5a Economic Security Analysis (January 2026)

Economic security analysis for detecting flash loan attacks, MEV exploitation, and DeFi protocol risks:

| Feature | Status | Tests |
|---------|--------|-------|
| Economic Summary API | Implemented | GET /scans/{id}/economic-analysis |
| Flash Loan Detection | Implemented | BVD-SOLIDITY-FLASH-* patterns |
| MEV Detection | Implemented | BVD-SOLIDITY-MEV-* patterns |
| DeFi Risk Detection | Implemented | BVD-SOLIDITY-DEFI-* patterns |
| AI Explanations | Implemented | Tier-gated quota system |
| Economic Risk Scoring | Implemented | Weighted calculation with multipliers |
| Dashboard Panel | Implemented | Economic Security panel in scan details |

**AI Explanation Quotas (4-Tier Model)**:
- Developer ($0): 0 (not available)
- Starter ($199/mo): 10/month
- Growth ($499/mo): 100/month
- Enterprise ($1,499+/mo): Unlimited

---

## Phase 5.5c CI/CD Quality Gates (January 2026)

Quality Gates for CI/CD pipeline integration with configurable blocking rules:

| Feature | Status | Tests |
|---------|--------|-------|
| Quality Gate Configuration | Implemented | GET/PUT /quality-gates/projects/{id} |
| Scan Evaluation | Implemented | POST /quality-gates/projects/{id}/evaluate |
| Build Status | Implemented | GET /quality-gates/projects/{id}/build-status |
| SVG Badge | Implemented | GET /quality-gates/projects/{id}/badge.svg |
| Evaluation History | Implemented | GET /quality-gates/projects/{id}/history |
| Dashboard Integration | Implemented | QualityGatePanel in ProjectDetail |
| Tier Gate | Implemented | Developer tier minimum |

**Dashboard Updates (v0.29.0)**:
- QualityGatePanel integrated into ProjectDetail page
- Contracts page search (filter by name/address)
- Advanced Search renamed from /search to /advanced-search
- Clickable contract links in Advanced Search results

---

## Cursor-Based Pagination (January 2026)

API pagination improvements for efficient large dataset navigation:

| Feature | Status | Tests |
|---------|--------|-------|
| Forward Pagination | Implemented | first/after params |
| Backward Pagination | Implemented | last/before params |
| Composite Indexes | Applied | Migration 029 |
| Offset Compatibility | Verified | skip/limit still work |
| Query Performance | Verified | EXPLAIN shows index scans |

---

## Phase 8a: Stripe Billing (January-February 2026)

Stripe integration for subscription billing. **Pending GCP deployment** for production webhooks.

| Feature | Status | Tests |
|---------|--------|-------|
| Stripe Checkout | Implemented | TC-37-001 |
| Subscription Management | Implemented | TC-37-002, 004, 005 |
| Customer Portal | Implemented | TC-37-006 |
| Invoice Downloads | Implemented | TC-37-003 |
| Billing Details | Implemented | TC-37-007 |
| Combined Billing History | Implemented | TC-37-008 |
| x402 Receipt PDFs | Implemented | TC-37-009 |
| Webhooks | Implemented | TC-37-010, 011 |
| Plan Upgrades | Implemented | TC-37-012 |
| Annual Billing | Implemented | TC-37-013 |
| **Dual Payment Options** | **Implemented (v0.36.0)** | TC-52-001 to 012 |

**Dual Payment Options (February 2026)**:
- Payment method selector on pricing page (Card/Crypto tabs)
- Stripe Checkout redirect for card payments
- x402 crypto wallet integration preserved
- Success/cancel redirect handling

**Note**: All tests pending GCP deployment for webhook verification.

---

## CI/CD Integrations (January 2026)

Notification channels and CLI tool for CI/CD integration:

| Feature | Status | Tests |
|---------|--------|-------|
| Notification Channels API | Implemented | Create/update/delete channels |
| Slack Notifications | Implemented | Block Kit formatting |
| Teams Notifications | Implemented | Adaptive Cards |
| Discord Notifications | Implemented | Rich embeds |
| CLI Tool | Implemented | Auth, scan, output formats |
| Pre-commit Hooks | Implemented | Git hook integration |
| SARIF Output | Implemented | GitHub/GitLab code scanning |
| JUnit Output | Implemented | CI test reporting |
| GitHub Actions | Implemented | Workflow, SARIF upload, PR comments |
| GitLab CI | Implemented | Pipeline, JUnit reports, Code Quality |
| Jenkins | Implemented | Freestyle, Pipeline, Multibranch |
| Azure Pipelines | Implemented | YAML pipeline, test results |

---

## GCP Launch Phase 2: Kubernetes Security (February 2026)

Kubernetes security configuration for GCP production deployment:

| Feature | Status | Tests |
|---------|--------|-------|
| revisionHistoryLimit | Implemented | All 8 deployments set to 3 |
| Pod Security Context | Implemented | runAsNonRoot, runAsUser, seccompProfile |
| Container Security Context | Implemented | allowPrivilegeEscalation=false, readOnlyRootFilesystem |
| NetworkPolicies | Implemented | Default-deny + service-specific rules |
| Dashboard Security | Implemented | Security context + NetworkPolicy added |

**Services Secured:**
- api-service, orchestration, tool-integration, dashboard
- data-service, intelligence-engine, notification, contract-parser

**Documentation:**
- [51-kubernetes-security.md](./51-kubernetes-security.md) - Feature tests
- [kubernetes-pod-lifecycle.md](../standards/kubernetes-pod-lifecycle.md) - Standards

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
| Semantic Deduplication | **Refactored (Jan 2026)** | HTTP calls to intelligence-engine |
| Smart Prioritization | Implemented | Priority ranking, composite scoring |

### ML Architecture Update (January 26, 2026)

ML embedding generation moved from api-service to intelligence-engine:

| Service | Before | After |
|---------|--------|-------|
| api-service | 12.6 GB (had PyTorch) | **934 MB** (lightweight HTTP client) |
| intelligence-engine | 3 GB | **1.89 GB** (hosts `/api/v1/embeddings`, trimmed Feb 8 2026) |

**Result:** 93% reduction in api-service image size. Deduplication functionality unchanged.

### Risk Scoring Redesign (December 30, 2025)

The risk scoring system was redesigned to be unbounded (higher = riskier):

- **Weights**: Critical=25, High=15, Medium=5, Low=1, Info=0
- **Thresholds** (per-contract avg): CRITICAL>=50, HIGH>=25, MEDIUM>=10, LOW<10
- **No cap**: Previously capped at 100, now accurately reflects total risk
- **New endpoint**: GET /api/v1/statistics/risk for per-project breakdown

---

## Phase 4.6 Platform Admin Panel (January 2026)

Internal admin panel for platform administrators with MFA, audit logging, and emergency controls:

| Feature | Status | Tests |
|---------|--------|-------|
| Admin CLI Tool | Implemented | create-admin, list, revoke, reset-mfa |
| MFA Authentication | Implemented | TOTP setup, verify, session management |
| User Management | Implemented | List, update tier, disable/enable |
| Organization Management | Implemented | List, view details |
| System Statistics | Implemented | Platform stats, health check |
| Audit Logs | Implemented | View admin actions, platform logs |
| Emergency Actions | Implemented | Revoke sessions, disable user, revoke admin |

**Admin Roles:**
- super_admin: Full platform access
- platform_admin: User/org management
- support_admin: Read-only access

**Security Features:**
- TOTP MFA (RFC 6238)
- IP-bound sessions (30 min timeout)
- Encrypted MFA secrets (Fernet)
- Permanent audit logs

---

## ML Data Strategy & Legal Compliance (January 2026)

GDPR/LGPD compliance features for ML data collection:

| Feature | Status | Tests |
|---------|--------|-------|
| ToS Consent Tracking | Implemented | Registration flow, consent API |
| ML Data Provenance | Implemented | Label tracking, feature snapshots |
| Organization AI Opt-Out | Implemented | Enterprise-only, admin API |
| GDPR Data Export | Implemented | Export request API |
| GDPR Data Deletion | Implemented | Deletion request API |

**Database Tables:**
- `tos_consent_records` - User consent with version tracking
- `ml_training_data_provenance` - Training data lineage
- `gdpr_data_requests` - Export/deletion request tracking

**Migrations:** 053, 054, 055

---

## Go-Live Audit

For the comprehensive GCP production launch audit (cross-cutting, integration-level, and production-readiness validation), see:

- **[Go-Live Audit Testing Checklist](../audits/GO-LIVE-AUDIT-TESTING-CHECKLIST.md)** - 14 sections, 140+ tests
- **Automation scripts:** `scripts/audit/` (tier quotas, auth, K8s security, database integrity, AppSec, smoke test)

---

## Test Notes

```
[Date] | [Tester] | [File] | [Result]
2026-03-02 | Manual | 89-gdpr-admin-data-requests.md | NEW - GDPR admin data requests: 7/7 tests passing. Deletion (anonymization), export (0600 perms), ML-withdrawal (10/10 provenance excluded), path traversal protection, scan error_message fix (v0.29.55 API, v0.7.10 Admin Portal)
2026-03-01 | Apogee Team | 88-referral-system.md | NEW - Referral system: 14/16 tests passing (2 pending: Stripe webhook, disable gate). Code gen, apply, self-referral block, rate limit, reward threshold, admin settings, dashboard UI (v0.29.49 API, v0.46.13 Dashboard)
2026-02-25 | Automated | 81-platform-security-audit.md | NEW - Full platform security audit: 145/145 tests passing across 5 audit suites (K8s, AppSec, Auth, DB integrity, Auth x402). 3 critical + 7 high + 8 medium issues remediated.
2026-02-16 | Apogee Team | GO-LIVE-AUDIT-TESTING-CHECKLIST.md | NEW - GCP production launch audit: 14 sections, 140+ cross-cutting tests, 6 automation scripts
2026-02-14 | Automated | 61-ai-inline-results.md | NEW - AI inline results: Code Review & Code Repair fully inline on vulnerability detail page, auth middleware fix for code-repair/copilot endpoints (v0.45.3 Dashboard, v0.28.32 API)
2026-02-12 | Apogee Team | 14-enterprise-features.md, 10-tier-upgrades.md, 37-stripe-billing.md | UPDATE - localStorage data isolation (userId-scoped keys), tier change modal tests, billing page invite card (v0.42.0 Dashboard)
2026-02-09 | Apogee Team | 60-collapsible-sidebar-quick-access.md | NEW - Collapsible sidebar + quick access page pins, localStorage persistence (v0.41.4 Dashboard)
2026-02-07 | Apogee Team | 59-admin-portal-v0.4.0.md | NEW - Admin Portal v0.4.0: GCP Cost Estimator, Scanners page, Dependencies endpoint (v0.4.0 Admin Portal, v0.27.7 API)
2026-02-01 | Apogee Team | 52-dual-payment-options.md | NEW - Dual Payment Options: Stripe + x402 crypto payment selector on pricing page (v0.36.0 Dashboard)
2026-02-01 | Apogee Team | 51-kubernetes-security.md | NEW - Kubernetes Security: revisionHistoryLimit, security contexts, NetworkPolicies, pod lifecycle (GCP Launch Phase 2)
2026-01-30 | Apogee Team | 48-ml-data-strategy.md | NEW - ML Data Strategy: consent tracking, provenance, GDPR compliance (v0.16.0 API, v0.34.0 Dashboard)
2026-01-26 | Apogee Team | 27-ai-ml-features.md | UPDATE - ML dependency split: embeddings moved to intelligence-engine, api-service reduced from 12.6GB to 934MB
2026-01-26 | Apogee Team | 24-cross-scanner-deduplication.md | UPDATE - Architecture change: semantic deduplication now uses intelligence-engine for embeddings
2026-01-23 | Apogee Team | 46-platform-admin-panel.md | NEW - Platform admin panel: MFA, user management, emergency actions (Phase 4.6)
2026-01-23 | Apogee Team | 44-platform-integrations.md | NEW - GitHub/GitLab/Bitbucket/Jira integrations, OAuth flow, repository import, Jira issue sync
2026-01-22 | Apogee Team | 43-dashboard-enhancement-jan2026.md | NEW - Dashboard layout, theme toggle, API key tier limits, vulnerability status, Users/Roles/RecentScans pages
2026-01-19 | Apogee Team | 42-ide-integration.md | IMPLEMENTED - IDE plugins (VS Code, JetBrains, Neovim), CLI --local flag, scan_source tracking (Migration 034)
2026-01-16 | Apogee Team | 16-user-activity-logging.md | FIX - Activity logging integration, events now logged on scan/contract/upload (v0.10.6 API)
2026-01-16 | Apogee Team | 24-cross-scanner-deduplication.md | FIX - Pattern code fallback to canonical finding (v0.10.6 API)
2026-01-15 | Apogee Team | 41-vulnerability-filtering.md | NEW - Severity filter, scanner dropdown, pattern input, copy button bug fixes (v0.10.3 API, v0.30.6 Dashboard)
2026-01-13 | Apogee Team | 25-dark-mode-global-search.md | FIX - Advanced Search filter overflow fixed, added Test 12 for filter layout (v0.29.0 Dashboard)
2026-01-12 | Apogee Team | 40-quality-gates.md | IMPLEMENTED - Quality Gates, ProjectDetail integration, contracts search, advanced-search rename (v0.10.2 API, v0.29.0 Dashboard)
2026-01-12 | Apogee Team | 25-dark-mode-global-search.md | UPDATED - Added Test 9-11 for advanced search, contracts search, contract links (v0.29.0 Dashboard)
2026-01-12 | Apogee Team | 39-economic-security-analysis.md | IMPLEMENTED - Economic panel, flash loan/MEV/DeFi detection, AI explanations (v0.10.0 API, v0.28.0 Dashboard)
2026-02-20 | Manual | 68-rate-limiting-security-audit.md | UPDATE - Added 10 remaining endpoint files (55+ endpoints) to rate limiting coverage, completing all non-exempt files (v0.29.5 API)
2026-02-19 | Manual | 70-platform-bugfixes-features.md | NEW - Platform bug fixes & features: 16 tasks across 4 services, pattern sorting, patterns view toggle, SCM PR creation, ML label fix, security hardening (v0.28.46 API, v0.45.9 Dashboard, v0.9.15 Orchestration, v0.4.8 Tool Integration)
2026-02-18 | Manual | 68-rate-limiting-security-audit.md | IMPLEMENTED - 28 rate limit decorators, 5 analytics dual-auth, webhook model fix (v0.28.42 API)
2026-01-10 | Manual | 38-cursor-pagination.md | VERIFIED - Migration 029 applied, indexes used in queries, cursor encode/decode working
2026-01-04 | Apogee Team | 36-cicd-integration.md | IMPLEMENTED - GitHub Actions, GitLab CI, Jenkins, Azure Pipelines integration tests
2026-01-04 | Apogee Team | 35-cli-tool.md | IMPLEMENTED - 0xapogee-cli v0.1.0, auth/scan commands, 4 output formats, pre-commit hooks
2026-01-04 | Apogee Team | 34-notification-channels.md | IMPLEMENTED - Migration 025, Slack/Teams/Discord notifiers, API endpoints (v0.7.1 API)
2025-12-31 | Apogee Team | 33-pricing-page-usage.md | IMPLEMENTED - CurrentPlanBanner, tier highlighting, WebSocket notification fix (v0.23.1 Dashboard)
2025-12-31 | Apogee Team | 32-contract-name-duplication.md | IMPLEMENTED - 409 conflict detection, DuplicateContractModal (v0.8.0 API, v0.22.0 Dashboard)
2025-12-30 | Apogee Team | 31-risk-scoring.md | PASS - Color badge display implemented (v0.21.0), replaces numeric 60.8k with "Critical Risk" badge
2025-12-30 | Apogee Team | 30-dashboard-production.md | PASS - Production build with build args verified
2025-12-30 | Apogee Team | 06-scanning.md (Sections 12.6, 13) | PASS - Fuzzer results display E2E verified
2025-12-28 | Apogee Team | 28-webapp-security.md | PASS - All security headers, CORS, request limits verified
2025-12-27 | Apogee Team | 27-ai-ml-features.md | PARTIAL - ML endpoints implemented, FP classifier needs training data
2025-12-27 | Apogee Team | 26-team-collaboration.md | PASS - Teams API, project access, assignments, comments verified
2025-12-26 | Apogee Team | 25-dark-mode-global-search.md | PASS - Dark mode persists, Command Palette works, Source code search verified
2025-12-25 | Apogee Team | 24-cross-scanner-deduplication.md | PASS - 137 groups, 421 findings deduplicated, API verified
2025-12-23 | Apogee Team | 23-vulnerability-categorization.md | PASS - All 832 vulns categorized, scan stats fixed
2025-12-22 | Manual | 13-vyper-rust-scanners.md | PASS - Phase 3.5 E2E integration complete
2025-12-22 | Manual | 06-scanning.md | PASS - Language-based scanner selection working
2025-12-21 | Apogee Team (Automated) | 06-scanning.md (Section 11) | PASS - Scanner Pattern Coverage validated
```
