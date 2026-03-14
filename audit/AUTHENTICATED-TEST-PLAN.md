# Authenticated Test Plan

**Version:** 1.0.0
**Created:** March 14, 2026
**Last Updated:** March 14, 2026
**Status:** Not Started
**Scope:** All platform checks requiring authenticated user sessions — API and UI
**Prerequisites:** Valid Supabase accounts across all tiers, Stripe test mode, configured notification channels

---

## Status Legend

| Symbol | Meaning |
|--------|---------|
| [ ] | Not tested |
| [x] | Passed |
| [!] | Failed — requires remediation |
| [~] | Partial — needs follow-up |

## Method Legend

| Method | Meaning |
|--------|---------|
| API | `curl` / HTTP client with JWT or API key |
| UI | Browser interaction required |
| API+UI | Both methods needed to fully validate |

---

## Test Accounts Required

| # | Account | Tier | Purpose |
|---|---------|------|---------|
| 1 | `dev-test@0xapogee.com` | Developer (Free) | Quota limits, feature gates, free tier restrictions |
| 2 | `starter-test@0xapogee.com` | Starter | Paid features, ML filtering, private repos |
| 3 | `growth-test@0xapogee.com` | Growth | API keys, service accounts, multi-chain, continuous monitoring |
| 4 | `enterprise-test@0xapogee.com` | Enterprise | SSO/SAML, JIRA, unlimited, custom SLA |
| 5 | `admin@0xapogee.com` | Admin | Admin portal access, user management |

### Obtaining a JWT Token (API tests)

```bash
SUPABASE_URL="https://huzjlpypdlelqnbjvxad.supabase.co"
SUPABASE_KEY="<anon-key>"

TOKEN=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: ${SUPABASE_KEY}" \
  -H "Content-Type: application/json" \
  -d '{"email":"<email>","password":"<password>"}' | \
  python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token',''))")
```

---

## Table of Contents

1. [Authentication & Login](#1-authentication--login)
2. [Session & Token Security](#2-session--token-security)
3. [API Key & Service Account Auth](#3-api-key--service-account-auth)
4. [RBAC & Authorization](#4-rbac--authorization)
5. [Tier Feature Gates](#5-tier-feature-gates)
6. [Quota & Rate Limiting](#6-quota--rate-limiting)
7. [Scan Workflow](#7-scan-workflow)
8. [Vulnerability & Deduplication](#8-vulnerability--deduplication)
9. [Billing & Payments](#9-billing--payments)
10. [Notification Channels](#10-notification-channels)
11. [VCS & CI/CD Integrations](#11-vcs--cicd-integrations)
12. [IDE & CLI Tooling](#12-ide--cli-tooling)
13. [Admin Portal](#13-admin-portal)
14. [Application Security (OWASP)](#14-application-security-owasp)
15. [Compliance & Data Privacy](#15-compliance--data-privacy)
16. [End-to-End Workflows](#16-end-to-end-workflows)

---

## 1. Authentication & Login

### 1.1 Email/Password Login

| # | Test | Method | Account | Expected | Status |
|---|------|--------|---------|----------|--------|
| 1.1.1 | Login with valid email/password | API | Any | JWT token returned, `access_token` non-empty | [ ] |
| 1.1.2 | Login with wrong password | API | Any | 400, `"Invalid login credentials"` | [ ] |
| 1.1.3 | Login with non-existent email | API | — | 400, no user enumeration (same error as wrong password) | [ ] |
| 1.1.4 | Login form renders on Dashboard | UI | — | Login page loads, Supabase auth UI visible | [ ] |
| 1.1.5 | Login form renders on Admin Portal | UI | — | Login page loads at `admin.0xapogee.com` | [ ] |
| 1.1.6 | Successful login redirects to Dashboard | UI | Any | Dashboard home page with user context | [ ] |

### 1.2 OAuth Login

| # | Test | Method | Provider | Expected | Status |
|---|------|--------|----------|----------|--------|
| 1.2.1 | Google OAuth login | UI | Google | Redirects to Google, returns with session | [ ] |
| 1.2.2 | GitHub OAuth login | UI | GitHub | Redirects to GitHub, returns with session | [ ] |
| 1.2.3 | Microsoft OAuth login | UI | Microsoft | Redirects to Microsoft, returns with session | [ ] |
| 1.2.4 | Discord OAuth login | UI | Discord | Redirects to Discord, returns with session | [ ] |

### 1.3 Wallet Authentication

| # | Test | Method | Wallet | Expected | Status |
|---|------|--------|--------|----------|--------|
| 1.3.1 | MetaMask wallet connect + signature | UI | MetaMask | Nonce signed, session created | [ ] |
| 1.3.2 | WalletConnect | UI | WalletConnect | QR code flow, session created | [ ] |
| 1.3.3 | Phantom (Solana) | UI | Phantom | Signature verified, session created | [ ] |

---

## 2. Session & Token Security

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 2.1 | JWT token contains correct claims (user_id, email, tier) | API | Claims present in decoded JWT | [ ] |
| 2.2 | Expired JWT rejected | API | 401 after token TTL | [ ] |
| 2.3 | Tampered JWT rejected (modified payload) | API | 401 | [ ] |
| 2.4 | Token not accessible via `document.cookie` (HttpOnly) | UI | Cookie not visible in JS console | [ ] |
| 2.5 | Cookie has `Secure` flag | UI | Cookie only sent over HTTPS | [ ] |
| 2.6 | Cookie has `SameSite=Lax` or `Strict` | UI | Attribute present in cookie | [ ] |
| 2.7 | Session invalidation on password change | API+UI | Old token returns 401 after password change | [ ] |
| 2.8 | Session invalidation on tier change | API+UI | Old token returns 401 after tier change | [ ] |
| 2.9 | Logout clears session | UI | Token removed, redirected to login | [ ] |

---

## 3. API Key & Service Account Auth

### 3.1 API Key (Growth+ only)

| # | Test | Method | Account | Expected | Status |
|---|------|--------|---------|----------|--------|
| 3.1.1 | Create API key | API | Growth | Key created with `bso_` prefix, value shown once | [ ] |
| 3.1.2 | Retrieve API key — only prefix shown | API | Growth | Full key not retrievable after creation | [ ] |
| 3.1.3 | Authenticate with `X-API-Key` header | API | Growth | 200, `last_used_at` updated | [ ] |
| 3.1.4 | API key with read-only scope can't write | API | Growth | 403 on POST/PUT/DELETE | [ ] |
| 3.1.5 | Expired API key rejected | API | Growth | 401 | [ ] |
| 3.1.6 | Revoked API key rejected | API | Growth | 401 | [ ] |
| 3.1.7 | API key refresh — old key immediately invalid | API | Growth | Old key 401, new key 200 | [ ] |
| 3.1.8 | Developer/Starter: API key creation denied | API | Developer, Starter | 403 tier gate | [ ] |

### 3.2 Service Accounts (Growth+ admin only)

| # | Test | Method | Account | Expected | Status |
|---|------|--------|---------|----------|--------|
| 3.2.1 | Create service account | API | Growth (admin) | Key with `bso_sa_` prefix | [ ] |
| 3.2.2 | Authenticate with `X-Service-Account-Key` | API | — | Authenticated, scoped | [ ] |
| 3.2.3 | Service account rate limits enforced | API | — | 429 after per/min threshold | [ ] |
| 3.2.4 | Non-admin Growth user can't create service account | API | Growth (member) | 403 | [ ] |
| 3.2.5 | Developer/Starter: service account creation denied | API | Developer, Starter | 403 tier gate | [ ] |

### 3.3 Internal Service Auth

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 3.3.1 | Internal endpoints without `X-Internal-Service-Key` | API | 401/403 from external | [ ] |
| 3.3.2 | Internal endpoints with valid key | API (from inside cluster) | 200 | [ ] |

---

## 4. RBAC & Authorization

| # | Test | Method | Account | Expected | Status |
|---|------|--------|---------|----------|--------|
| 4.1 | Org admin: full CRUD on org resources | API | Admin | All operations succeed | [ ] |
| 4.2 | Org member: read-only where restricted | API | Member | Write operations return 403 | [ ] |
| 4.3 | Cross-org isolation: access another org's scan | API | Any | 403 or 404 | [ ] |
| 4.4 | Cross-org isolation: access another org's vulnerability | API | Any | 403 or 404 | [ ] |
| 4.5 | Admin portal: non-admin user | UI | Non-admin | 403 or redirect to login | [ ] |
| 4.6 | Write endpoint uses `require_auth_with_scope()` | API | API key with wrong scope | 403 | [ ] |
| 4.7 | Resource ownership: edit another user's scan | API | Different user | 403 | [ ] |

---

## 5. Tier Feature Gates

### 5.1 Developer Tier (Free)

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 5.1.1 | Scan limit: 4th scan in month blocked | API | 402 quota error | [ ] |
| 5.1.2 | Private repo scanning denied | API+UI | Denied with tier gate message | [ ] |
| 5.1.3 | API key creation denied | API | 403 (Growth+ only) | [ ] |
| 5.1.4 | IDE token generation denied | API | 403 (Starter+ only) | [ ] |
| 5.1.5 | ML false positive filtering not applied | API | Raw results, no FP filtering | [ ] |
| 5.1.6 | Multi-chain scanning denied (Vyper/Rust) | API+UI | Denied (Growth+ only) | [ ] |
| 5.1.7 | Continuous monitoring denied | API+UI | Denied (Growth+ only) | [ ] |
| 5.1.8 | Compliance reports not available | API+UI | Denied (Starter+ only) | [ ] |
| 5.1.9 | Public repositories only enforced | API+UI | Cannot add private repos | [ ] |

### 5.2 Starter Tier

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 5.2.1 | Scan limit: 26th scan in month blocked | API | 402 quota error | [ ] |
| 5.2.2 | Private repos allowed (up to 5) | API+UI | Can add private repos | [ ] |
| 5.2.3 | ML false positive filtering active | API | FP-flagged findings present | [ ] |
| 5.2.4 | IDE token generation allowed | API | Token created | [ ] |
| 5.2.5 | Slack/Discord/email alerts work | API+UI | Notifications delivered | [ ] |
| 5.2.6 | Basic compliance reports (SOC 2 mapping) | API+UI | Report generated | [ ] |
| 5.2.7 | Multi-chain scanning denied | API+UI | Denied (Growth+ only) | [ ] |
| 5.2.8 | API key creation denied | API | 403 (Growth+ only) | [ ] |
| 5.2.9 | Continuous monitoring denied | API+UI | Denied (Growth+ only) | [ ] |

### 5.3 Growth Tier

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 5.3.1 | Scan limit: 76th scan in month blocked | API | 402 quota error | [ ] |
| 5.3.2 | API key creation allowed | API | Key created | [ ] |
| 5.3.3 | Service account creation allowed (admin) | API | Service account created | [ ] |
| 5.3.4 | Multi-chain scanning allowed (Vyper, Rust/Solana) | API+UI | Scanners available, results returned | [ ] |
| 5.3.5 | Continuous monitoring enabled | API+UI | Post-deployment monitoring active | [ ] |
| 5.3.6 | API access for custom integrations | API | Endpoints accessible via API key | [ ] |
| 5.3.7 | Audit-ready PDF reports | API+UI | PDF generated with remediation guidance | [ ] |
| 5.3.8 | Custom rule configuration | API+UI | Rules configurable | [ ] |
| 5.3.9 | Real-time security dashboards | UI | Dashboards render live data | [ ] |
| 5.3.10 | SSO/SAML denied | API+UI | Denied (Enterprise only) | [ ] |
| 5.3.11 | JIRA integration denied | API+UI | Denied (Enterprise only) | [ ] |

### 5.4 Enterprise Tier

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 5.4.1 | Unlimited scans | API | No quota block | [ ] |
| 5.4.2 | SSO/SAML enabled | UI | SSO login flow works | [ ] |
| 5.4.3 | JIRA integration available | API+UI | OAuth flow, issue creation works | [ ] |
| 5.4.4 | White-label reports | API+UI | Custom branding applied | [ ] |
| 5.4.5 | Dedicated security advisor visible | UI | Named contact in settings | [ ] |
| 5.4.6 | Executive reporting dashboards | UI | Board-ready reports generated | [ ] |

---

## 6. Quota & Rate Limiting

### 6.1 Scan Quotas

| # | Test | Method | Tier | Limit | Expected | Status |
|---|------|--------|------|-------|----------|--------|
| 6.1.1 | Developer: exceed 3 scans/month | API | Developer | 3 | 402 on 4th scan | [ ] |
| 6.1.2 | Starter: exceed 25 scans/month | API | Starter | 25 | 402 on 26th scan | [ ] |
| 6.1.3 | Growth: exceed 75 scans/month | API | Growth | 75 | 402 on 76th scan | [ ] |
| 6.1.4 | Enterprise: no quota block | API | Enterprise | Unlimited | Scan proceeds | [ ] |
| 6.1.5 | Monthly quota reset (verify cron) | API | Any | Counters reset to 0 | [ ] |

### 6.2 Concurrent Scan Limits

| # | Test | Method | Tier | Limit | Expected | Status |
|---|------|--------|------|-------|----------|--------|
| 6.2.1 | Developer: 2nd concurrent scan blocked | API | Developer | 1 | Queued | [ ] |
| 6.2.2 | Starter: 3rd concurrent scan blocked | API | Starter | 2 | Queued | [ ] |
| 6.2.3 | Growth: 6th concurrent scan blocked | API | Growth | 5 | Queued | [ ] |

### 6.3 Rate Limiting

| # | Test | Method | Tier | Expected | Status |
|---|------|--------|------|----------|--------|
| 6.3.1 | Developer: burst requests | API | Developer | 429 after threshold | [ ] |
| 6.3.2 | Starter: burst requests | API | Starter | 429 after threshold | [ ] |
| 6.3.3 | Growth: > 300 req/min | API | Growth | 429 after 300/min | [ ] |
| 6.3.4 | Cloud Armor: > 30 req/min per IP | API | Any | Rate-based ban (WAF rule 2000) | [ ] |

### 6.4 Usage-Based Overage

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 6.4.1 | Additional contract at $19/contract (over tier limit) | API+UI | Charge applied, scan proceeds | [ ] |
| 6.4.2 | Express scan ($99/scan, 4hr turnaround) | API+UI | Prioritized scan, charge applied | [ ] |

---

## 7. Scan Workflow

### 7.1 Upload & Initiate

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 7.1.1 | Upload single .sol file | API | File accepted, contract created | [ ] |
| 7.1.2 | Upload .vy file (Growth+) | API | File accepted, Vyper scanners offered | [ ] |
| 7.1.3 | Upload .rs file (Growth+) | API | File accepted, Rust scanners offered | [ ] |
| 7.1.4 | Upload .zip project | API | Extracted, multi-file scan initiated | [ ] |
| 7.1.5 | Upload disallowed file type (.exe, .py) | API | 422 rejected | [ ] |
| 7.1.6 | Upload file > size limit | API | 413 or 422 rejected | [ ] |
| 7.1.7 | Upload via Dashboard drag-and-drop | UI | File accepted, scanner selection shown | [ ] |

### 7.2 Scanner Selection & Execution

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 7.2.1 | Select subset of scanners | API+UI | Only selected scanners execute | [ ] |
| 7.2.2 | Language auto-detection → correct scanners | UI | Solidity → Slither/Aderyn/etc, Vyper → Vyper/Moccasin | [ ] |
| 7.2.3 | Fuzzers require project mode | API+UI | Single-file upload blocked with clear error | [ ] |
| 7.2.4 | Scan status progression: queued → running → completed | API+UI | WebSocket updates + API polling both work | [ ] |
| 7.2.5 | Scan results displayed with findings | UI | Vulnerability list rendered | [ ] |
| 7.2.6 | Multi-scanner comparison view | UI | Side-by-side comparison with dedup | [ ] |

### 7.3 Scan Results & History

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 7.3.1 | GET /api/v1/scans returns scan list | API | 200 with paginated results | [ ] |
| 7.3.2 | GET /api/v1/scans/{id} returns scan detail | API | 200 with findings, scanner info | [ ] |
| 7.3.3 | GET /api/v1/vulnerabilities returns vuln list | API | 200 with severity, category, scanner | [ ] |
| 7.3.4 | GET /api/v1/scanners returns scanner metadata | API | 200 with 16 scanners, versions, developers | [ ] |
| 7.3.5 | POST /api/v1/search with query | API | 200 with matching results | [ ] |
| 7.3.6 | Scan history: previous scans retrievable | API+UI | Historical scans listed | [ ] |

### 7.4 Reports

| # | Test | Method | Tier | Expected | Status |
|---|------|--------|------|----------|--------|
| 7.4.1 | Basic vulnerability report | API+UI | All | Report generated with findings | [ ] |
| 7.4.2 | Compliance report (SOC 2 mapping) | API+UI | Starter+ | Compliance sections populated | [ ] |
| 7.4.3 | Audit-ready PDF report | API+UI | Growth+ | PDF with remediation guidance | [ ] |
| 7.4.4 | White-label report | API+UI | Enterprise | Custom branding applied | [ ] |

---

## 8. Vulnerability & Deduplication

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 8.1 | Cross-scanner dedup: same vuln from Slither + Aderyn | API | Grouped into single dedup group | [ ] |
| 8.2 | GET /api/v1/deduplication/groups returns groups | API | 200 with group data | [ ] |
| 8.3 | Fingerprint types populated (code, location, AST, semantic) | API | All 4 columns non-null | [ ] |
| 8.4 | ML false positive prediction (Starter+) | API | FP-flagged findings present | [ ] |
| 8.5 | RLHF feedback: confirm/reject FP | API+UI | Feedback recorded | [ ] |
| 8.6 | Risk scoring: project risk score + level | API | Score + CRITICAL/HIGH/MEDIUM/LOW | [ ] |
| 8.7 | AI inline vulnerability explanation (Claude API) | UI | Explanation rendered on detail page | [ ] |
| 8.8 | Vulnerability classification to BVD code | API | Correct category assigned | [ ] |

---

## 9. Billing & Payments

### 9.1 Stripe Subscription

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 9.1.1 | Pricing page: correct tiers, features, prices | UI | Matches `tiers.json` (Dev $0, Starter $199, Growth $499, Enterprise $1,499+) | [ ] |
| 9.1.2 | Developer → Starter upgrade via Stripe Checkout | UI | Redirects to Stripe, tier updated on return | [ ] |
| 9.1.3 | Starter → Growth upgrade | UI | Immediate feature unlock, prorated charge | [ ] |
| 9.1.4 | Growth → Starter downgrade | UI | Effective at renewal period end | [ ] |
| 9.1.5 | Subscription cancellation | UI | Downgrade to Developer at period end | [ ] |
| 9.1.6 | Annual billing discount (15%) | UI | Correct annual price shown | [ ] |
| 9.1.7 | Payment failure: test card declined | UI | Graceful error, no tier change | [ ] |
| 9.1.8 | Invoice generation and retrieval | API+UI | Invoice accessible | [ ] |

### 9.2 Stripe Webhooks

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 9.2.1 | Valid webhook signature processed | API | Event processed, tier updated | [ ] |
| 9.2.2 | Invalid/tampered webhook signature | API | 400 rejected | [ ] |
| 9.2.3 | Webhook idempotency: duplicate event | API | Processed once, no double-charge | [ ] |
| 9.2.4 | Webhook tier metadata validation | API | Tier matches Stripe product | [ ] |

### 9.3 x402 Credits

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 9.3.1 | USDC payment on Base mainnet | UI | Credit applied to account | [ ] |
| 9.3.2 | Credit balance tracking | API+UI | Balance decrements per scan | [ ] |
| 9.3.3 | Insufficient credits blocks scan | API | Clear error, scan not started | [ ] |
| 9.3.4 | Credit packages at correct prices | UI | Starter $25, Builder $99, Pro $399, Bulk $1,250 | [ ] |

---

## 10. Notification Channels

### 10.1 Channel Configuration

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 10.1.1 | Add Slack webhook channel | UI | Channel saved, test notification sent | [ ] |
| 10.1.2 | Add Discord webhook channel | UI | Channel saved, test notification sent | [ ] |
| 10.1.3 | Add Teams webhook channel | UI | Channel saved, test notification sent | [ ] |
| 10.1.4 | Add email notification channel | UI | Channel saved | [ ] |
| 10.1.5 | Test notification delivery button | UI | Message received in channel | [ ] |
| 10.1.6 | Remove notification channel | UI | Channel deleted | [ ] |

### 10.2 Notification Delivery

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 10.2.1 | Scan complete → Slack notification | API+UI | Message received with scan summary | [ ] |
| 10.2.2 | Critical finding → email alert | API+UI | Email delivered with vulnerability details | [ ] |
| 10.2.3 | Webhook message history viewable | UI | History with status/timestamps | [ ] |
| 10.2.4 | WebSocket real-time scan progress | UI | Live progress bar updates on dashboard | [ ] |

---

## 11. VCS & CI/CD Integrations

### 11.1 VCS OAuth

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 11.1.1 | GitHub: connect OAuth | UI | OAuth flow completes, repos listed | [ ] |
| 11.1.2 | GitHub: list repositories | API+UI | Repos displayed | [ ] |
| 11.1.3 | GitHub: disconnect | UI | Integration removed | [ ] |
| 11.1.4 | GitLab: connect, list repos, disconnect | UI | Full lifecycle | [ ] |
| 11.1.5 | Bitbucket: connect, list repos, disconnect | UI | Full lifecycle | [ ] |

### 11.2 CI/CD Pipelines

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 11.2.1 | GitHub Action: trigger scan on push | API | Scan triggered, quality gate evaluates | [ ] |
| 11.2.2 | GitHub Action: pass/fail badge returned | API | Badge reflects scan result | [ ] |
| 11.2.3 | GitLab CI: trigger scan, quality gate | API | Pass/fail returned | [ ] |

### 11.3 Issue Tracking

| # | Test | Method | Tier | Expected | Status |
|---|------|--------|------|----------|--------|
| 11.3.1 | JIRA: OAuth connect (Enterprise) | UI | Enterprise | OAuth flow completes | [ ] |
| 11.3.2 | JIRA: create issue from finding | API+UI | Enterprise | JIRA issue created with vuln details | [ ] |
| 11.3.3 | JIRA: non-Enterprise denied | API+UI | Non-Enterprise | Tier gate message | [ ] |

---

## 12. IDE & CLI Tooling

### 12.1 CLI

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 12.1.1 | `0xapogee-cli` install via pip | CLI | Installs without error | [ ] |
| 12.1.2 | CLI configure with API key | CLI | Config saved, auth test passes | [ ] |
| 12.1.3 | CLI scan: upload .sol file | CLI | Scan initiated, results returned | [ ] |
| 12.1.4 | CLI report generation | CLI | Report downloaded | [ ] |
| 12.1.5 | CLI default endpoint is `https://api.0xapogee.com` | CLI | Correct URL configured | [ ] |

### 12.2 IDE Extensions

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 12.2.1 | IDE token generation (Starter+) | API+UI | Token created, displayed once | [ ] |
| 12.2.2 | IDE token retrieval after creation | API | Only prefix shown | [ ] |
| 12.2.3 | VS Code: configure extension with token | UI (VS Code) | Extension authenticates | [ ] |
| 12.2.4 | VS Code: trigger scan from editor | UI (VS Code) | Scan runs, results shown in editor | [ ] |
| 12.2.5 | IntelliJ: configure and trigger scan | UI (IntelliJ) | Scan runs, results shown | [ ] |
| 12.2.6 | Neovim: delegates to CLI | CLI | Scan completes via CLI | [ ] |
| 12.2.7 | Developer tier: IDE token generation denied | API | 403 (Starter+ only) | [ ] |

---

## 13. Admin Portal

| # | Test | Method | Account | Expected | Status |
|---|------|--------|---------|----------|--------|
| 13.1 | Admin portal loads at `admin.0xapogee.com` | UI | Admin | 200, dashboard renders | [ ] |
| 13.2 | Non-admin user cannot access | UI | Non-admin | 403 or redirect | [ ] |
| 13.3 | User list: view all users | UI | Admin | User table with tiers | [ ] |
| 13.4 | Change user tier | UI | Admin | Tier updated, session invalidated | [ ] |
| 13.5 | Circuit breaker: view service group status | UI | Admin | 8 service groups shown | [ ] |
| 13.6 | Circuit breaker: force reset | UI | Admin | Service group recovers | [ ] |
| 13.7 | Dependency monitor: external service health | UI | Admin | Health status displayed | [ ] |
| 13.8 | MFA enforcement for admin accounts | UI | Admin | MFA prompt on login | [ ] |

---

## 14. Application Security (OWASP)

### 14.1 Injection

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 14.1.1 | SQL injection on search endpoint | API | Parameterized, no data leak | [ ] |
| 14.1.2 | SQL injection on login | API | No bypass, parameterized | [ ] |
| 14.1.3 | Command injection via contract filename | API | Filename sanitized | [ ] |
| 14.1.4 | Prompt injection in contract comments → AI explanation | API | Sanitized before LLM call | [ ] |

### 14.2 XSS & CSRF

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 14.2.1 | Stored XSS: malicious contract name | API+UI | Output encoded in UI | [ ] |
| 14.2.2 | Reflected XSS: malicious URL params | UI | Output encoded | [ ] |
| 14.2.3 | CSRF: forged state-changing request | API | Rejected without valid CSRF token | [ ] |

### 14.3 SSRF & File Security

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 14.3.1 | SSRF via webhook URL (internal IP) | API | Internal network blocked | [ ] |
| 14.3.2 | Path traversal in file upload | API | Traversal blocked | [ ] |

### 14.4 Response Security

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 14.4.1 | Error response: no stack traces | API | Generic error messages only | [ ] |
| 14.4.2 | Non-existent resource: no internal details | API | `"Not found"`, no paths or IDs leaked | [ ] |
| 14.4.3 | Security headers present | API | CSP, X-Frame-Options, HSTS, X-Content-Type-Options | [ ] |
| 14.4.4 | CORS: unauthorized origin blocked | API | No `Access-Control-Allow-Origin` for `evil.com` | [ ] |
| 14.4.5 | CORS: no wildcard with credentials | API | Rejected | [ ] |
| 14.4.6 | No server version disclosure | API | `Server` header absent or generic | [ ] |

---

## 15. Compliance & Data Privacy

| # | Test | Method | Expected | Status |
|---|------|--------|----------|--------|
| 15.1 | Audit trail: auth events logged | API | Login/logout in audit_logs table | [ ] |
| 15.2 | Audit trail: tier change logged | API | Tier changes in audit_logs | [ ] |
| 15.3 | Audit log immutability: UPDATE blocked | API (DB) | Trigger rejects UPDATE | [ ] |
| 15.4 | Audit log immutability: DELETE blocked | API (DB) | Trigger rejects DELETE | [ ] |
| 15.5 | GDPR: ML data consent opt-in/out | API+UI | Consent toggle works, state respected | [ ] |
| 15.6 | GDPR: data export request | API+UI | Export delivered | [ ] |
| 15.7 | GDPR: account deletion request | API+UI | Account and data removed | [ ] |

---

## 16. End-to-End Workflows

These tests validate complete user journeys that span multiple components.

| # | Workflow | Method | Steps | Expected | Status |
|---|---------|--------|-------|----------|--------|
| 16.1 | New user onboarding | UI | Register → free tier → first scan → results | Smooth flow, correct tier gates | [ ] |
| 16.2 | Full scan lifecycle | API+UI | Upload → select scanners → scan → results → dedup → report | Complete flow, no errors | [ ] |
| 16.3 | Tier upgrade flow | UI | Developer → Starter → Growth (Stripe checkout each step) | Features unlock at each tier | [ ] |
| 16.4 | CI/CD pipeline | API | GitHub Action → scan trigger → quality gate → badge | Pass/fail badge returned | [ ] |
| 16.5 | Notification flow | API+UI | Scan completes → webhook fires → Slack message | End-to-end delivery | [ ] |
| 16.6 | IDE workflow | UI (VS Code) | Generate token → configure VS Code → scan → results | Full IDE loop | [ ] |
| 16.7 | Admin workflow | UI | Admin portal → view users → change tier → verify enforcement | Actions propagate | [ ] |
| 16.8 | 14-day reverse trial | UI | New signup → Starter features for 14 days → drops to Developer | Feature access changes correctly | [ ] |
| 16.9 | Cross-scanner dedup | API+UI | Submit contract → multiple scanners → dedup groups formed | Same vuln grouped | [ ] |
| 16.10 | ML false positive | API+UI | Submit known FP contract → ML flags as likely FP | Confidence score shown | [ ] |

---

## Test Execution Log

| Date | Tester | Sections | Method | Result | Notes |
|------|--------|----------|--------|--------|-------|
| | | | | | |

---

## Related Documents

- [Platform Audit Checklist](./PLATFORM-AUDIT-CHECKLIST.md) — Infrastructure audit (sections tested via cluster inspection)
- [Comprehensive Platform Audit (v11)](./COMPREHENSIVE-PLATFORM-AUDIT.md) — Previous audit results
- [Pricing Tiers](../pricing/pricing-tiers.md) — Tier definitions, quotas, pricing
- [API Endpoint Auth Standards](../standards/api-endpoint-auth.md) — Auth dependency selection
- [Smoke Test](../standards/smoke-test.md) — Post-deployment smoke tests
- [Tier Standards](../standards/tier-standards.md) — Tier-based feature access
