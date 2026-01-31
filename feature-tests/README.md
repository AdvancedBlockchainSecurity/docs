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
- GitHub/GitLab/Bitbucket: Team+ tier
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
- Team ($299/mo): 10/month
- Growth ($699/mo): 100/month
- Enterprise ($1,999+/mo): Unlimited

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

## Phase 8a: Stripe Billing (January 2026)

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
| intelligence-engine | 3 GB | 3 GB (hosts `/api/v1/embeddings`) |

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

## Test Notes

```
[Date] | [Tester] | [File] | [Result]
2026-01-30 | Claude Code | 48-ml-data-strategy.md | NEW - ML Data Strategy: consent tracking, provenance, GDPR compliance (v0.16.0 API, v0.34.0 Dashboard)
2026-01-26 | Claude Code | 27-ai-ml-features.md | UPDATE - ML dependency split: embeddings moved to intelligence-engine, api-service reduced from 12.6GB to 934MB
2026-01-26 | Claude Code | 24-cross-scanner-deduplication.md | UPDATE - Architecture change: semantic deduplication now uses intelligence-engine for embeddings
2026-01-23 | Claude Code | 46-platform-admin-panel.md | NEW - Platform admin panel: MFA, user management, emergency actions (Phase 4.6)
2026-01-23 | Claude Code | 44-platform-integrations.md | NEW - GitHub/GitLab/Bitbucket/Jira integrations, OAuth flow, repository import, Jira issue sync
2026-01-22 | Claude Code | 43-dashboard-enhancement-jan2026.md | NEW - Dashboard layout, theme toggle, API key tier limits, vulnerability status, Users/Roles/RecentScans pages
2026-01-19 | Claude Code | 42-ide-integration.md | IMPLEMENTED - IDE plugins (VS Code, JetBrains, Neovim), CLI --local flag, scan_source tracking (Migration 034)
2026-01-16 | Claude Code | 16-user-activity-logging.md | FIX - Activity logging integration, events now logged on scan/contract/upload (v0.10.6 API)
2026-01-16 | Claude Code | 24-cross-scanner-deduplication.md | FIX - Pattern code fallback to canonical finding (v0.10.6 API)
2026-01-15 | Claude Code | 41-vulnerability-filtering.md | NEW - Severity filter, scanner dropdown, pattern input, copy button bug fixes (v0.10.3 API, v0.30.6 Dashboard)
2026-01-13 | Claude Code | 25-dark-mode-global-search.md | FIX - Advanced Search filter overflow fixed, added Test 12 for filter layout (v0.29.0 Dashboard)
2026-01-12 | Claude Code | 40-quality-gates.md | IMPLEMENTED - Quality Gates, ProjectDetail integration, contracts search, advanced-search rename (v0.10.2 API, v0.29.0 Dashboard)
2026-01-12 | Claude Code | 25-dark-mode-global-search.md | UPDATED - Added Test 9-11 for advanced search, contracts search, contract links (v0.29.0 Dashboard)
2026-01-12 | Claude Code | 39-economic-security-analysis.md | IMPLEMENTED - Economic panel, flash loan/MEV/DeFi detection, AI explanations (v0.10.0 API, v0.28.0 Dashboard)
2026-01-10 | Claude Code | 38-cursor-pagination.md | VERIFIED - Migration 029 applied, indexes used in queries, cursor encode/decode working
2026-01-04 | Claude Code | 36-cicd-integration.md | IMPLEMENTED - GitHub Actions, GitLab CI, Jenkins, Azure Pipelines integration tests
2026-01-04 | Claude Code | 35-cli-tool.md | IMPLEMENTED - blocksecops-cli v0.1.0, auth/scan commands, 4 output formats, pre-commit hooks
2026-01-04 | Claude Code | 34-notification-channels.md | IMPLEMENTED - Migration 025, Slack/Teams/Discord notifiers, API endpoints (v0.7.1 API)
2025-12-31 | Claude Code | 33-pricing-page-usage.md | IMPLEMENTED - CurrentPlanBanner, tier highlighting, WebSocket notification fix (v0.23.1 Dashboard)
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
